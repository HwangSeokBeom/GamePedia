import Combine
import Foundation

// MARK: - HomeViewModel
//
// Data flow:
//   HomeIntent → HomeViewModel → APIClient → AuthService → IGDB
//   IGDB response → [IGDBGameDTO] → IGDBGameMapper → [Game] → HomeMutation → HomeReducer → HomeState → UI

final class HomeViewModel {

    // MARK: State
    private(set) var state: HomeState = HomeState() {
        didSet { onStateChanged?(state) }
    }

    // MARK: Output — ViewController binds this
    var onStateChanged: ((HomeState) -> Void)?
    var onRoute: ((HomeRoute) -> Void)?

    // MARK: Dependencies
    private let loadHomeFeedUseCase: LoadHomeFeedUseCase
    private let userActivityRepository: any UserActivityRepository
    private let fetchMyFavoritesUseCase: FetchMyFavoritesUseCase
    private let translateTextUseCase: TranslateTextUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init
    init(
        loadHomeFeedUseCase: LoadHomeFeedUseCase? = nil,
        userActivityRepository: (any UserActivityRepository)? = nil,
        fetchMyFavoritesUseCase: FetchMyFavoritesUseCase = FetchMyFavoritesUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        translateTextUseCase: TranslateTextUseCase? = nil
    ) {
        let resolvedActivityRepository = userActivityRepository ?? LocalUserActivityRepository.shared
        self.userActivityRepository = resolvedActivityRepository
        self.loadHomeFeedUseCase = loadHomeFeedUseCase ?? LoadHomeFeedUseCase.live(
            userActivityRepository: resolvedActivityRepository
        )
        self.fetchMyFavoritesUseCase = fetchMyFavoritesUseCase
        self.translateTextUseCase = translateTextUseCase ?? DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        )
        observeFavoriteChanges()
    }

    // MARK: - Intent Processing

    func send(_ intent: HomeIntent) {
        switch intent {
        case .viewDidLoad:
            loadHomeData()
        case .didTapGame(let game):
            Task {
                await userActivityRepository.recordViewed(game: game)
            }
        case .didTapSeeMore(let section):
            routeToSectionList(section)
        case .didTapNotification:
            break   // navigation handled by ViewController
        }
    }

    // MARK: - Private

    private func apply(_ mutation: HomeMutation) {
        state = HomeReducer.reduce(state, mutation)
    }

    private func loadHomeData() {
        apply(.setLoading(true))

        Task {
            do {
                async let feedTask = loadHomeFeedUseCase.execute()
                async let favoritesTask = fetchMyFavoritesUseCase.execute(sort: .latest)
                let feed = try await feedTask
                let favoriteItems = (try? await favoritesTask) ?? []
                let translatedFeed = await translateHomeFeed(feed)
                await MainActor.run {
                    self.apply(.setHomeFeed(translatedFeed))
                    self.apply(.setWishlistedGameIDs(Set(favoriteItems.map(\.gameId))))
                    self.apply(.setLoading(false))
                }
            } catch {
                await MainActor.run {
                    self.apply(.setError(error.localizedDescription))
                }
            }
        }
    }

    private func observeFavoriteChanges() {
        NotificationCenter.default.publisher(for: .favoriteDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let gameId = notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int,
                      let isFavorite = notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool else {
                    return
                }

                var updatedIDs = self.state.wishlistedGameIDs
                if isFavorite {
                    updatedIDs.insert(gameId)
                } else {
                    updatedIDs.remove(gameId)
                }
                self.apply(.setWishlistedGameIDs(updatedIDs))
            }
            .store(in: &cancellables)
    }

    private func routeToSectionList(_ section: HomeSection) {
        let games: [Game]
        switch section {
        case .todayRecommendation:
            games = state.todayRecommendations.map(\.game)
        case .popular:
            games = state.popularGames
        case .trending:
            games = state.trendingGames
        }

        guard !games.isEmpty else { return }
        onRoute?(
            .showGameList(
                section: section,
                games: games,
                wishlistedGameIDs: state.wishlistedGameIDs
            )
        )
    }

    private func translateHomeFeed(_ feed: HomeFeed) async -> HomeFeed {
        async let translatedHighlights = translateHighlights(feed.highlights)
        async let translatedTodayRecommendations = translateTodayRecommendations(feed.todayRecommendations)
        async let translatedPopularGames = translateGames(feed.popularGames, context: "Home.popular")
        async let translatedTrendingGames = translateGames(feed.trendingGames, context: "Home.trending")

        let (highlights, todayRecommendations, popularGames, trendingGames) = await (
            translatedHighlights,
            translatedTodayRecommendations,
            translatedPopularGames,
            translatedTrendingGames
        )
        return HomeFeed(
            highlights: highlights,
            todayRecommendations: todayRecommendations,
            popularGames: popularGames,
            trendingGames: trendingGames
        )
    }

    private func translateHighlights(_ highlights: [HomeHighlightItem]) async -> [HomeHighlightItem] {
        let translatedGames = await translateGames(
            highlights.map(\.game),
            context: "highlight",
            translateSummary: true
        )
        let gamesByID = Dictionary(uniqueKeysWithValues: translatedGames.map { ($0.id, $0) })
        return highlights.map { item in
            let translatedGame = gamesByID[item.game.id] ?? item.game
            return HomeHighlightItem(
                game: translatedGame,
                badgeText: item.badgeText,
                titleText: translatedGame.resolvedTitle,
                metaText: item.metaText,
                supportingText: item.supportingText
            )
        }
    }

    private func translateTodayRecommendations(_ recommendations: [TodayRecommendation]) async -> [TodayRecommendation] {
        let translatedGames = await translateGames(recommendations.map(\.game), context: "home.today")
        let gamesByID = Dictionary(uniqueKeysWithValues: translatedGames.map { ($0.id, $0) })
        return recommendations.map { recommendation in
            TodayRecommendation(
                game: gamesByID[recommendation.game.id] ?? recommendation.game,
                score: recommendation.score,
                primaryReason: recommendation.primaryReason,
                reasons: recommendation.reasons,
                scoreBreakdown: recommendation.scoreBreakdown,
                source: recommendation.source
            )
        }
    }

    private func translateGames(
        _ games: [Game],
        context: String,
        translateSummary: Bool = false
    ) async -> [Game] {
        guard !games.isEmpty else { return games }

        let titleItems = games.compactMap { game -> TranslationRequestItem? in
            guard game.translatedTitle == nil else { return nil }
            return TranslationRequestItem(
                identifier: String(game.id),
                field: "title",
                text: game.title
            )
        }

        let summaryItems = translateSummary
            ? games.compactMap { game -> TranslationRequestItem? in
                guard let summary = game.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !summary.isEmpty else { return nil }
                return TranslationRequestItem(
                    identifier: String(game.id),
                    field: "summary",
                    text: summary
                )
            }
            : []

        guard !titleItems.isEmpty || !summaryItems.isEmpty else { return games }

        async let titleResults = translateTextUseCase.execute(
            items: titleItems,
            context: "\(context).title",
            sourceLanguage: "en"
        )
        async let summaryResults = translateTextUseCase.execute(
            items: summaryItems,
            context: "\(context).summary",
            sourceLanguage: "en"
        )
        let translatedTitles = Dictionary(uniqueKeysWithValues: await titleResults.map { ($0.identifier, $0.translatedText) })
        let translatedSummaries = Dictionary(uniqueKeysWithValues: await summaryResults.map { ($0.identifier, $0.translatedText) })

        return games.map { game in
            game.replacingTranslated(
                translatedTitle: translatedTitles[String(game.id)],
                translatedSummary: translatedSummaries[String(game.id)]
            )
        }
    }
}

private extension Array where Element == Game {
    func deduplicatedGames() -> [Game] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}
