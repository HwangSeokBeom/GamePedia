import Combine
import Foundation

// MARK: - HomeViewModel
//
// Data flow:
//   HomeIntent → HomeViewModel → LoadHomeFeedUseCase → GamePediaCoreServer
//   backend response → DTO → GameMapper → [Game] → HomeMutation → HomeReducer → HomeState → UI

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
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let translateTextUseCase: TranslateTextUseCase
    private let fetchUnreadNotificationCountUseCase: FetchUnreadNotificationCountUseCase
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init
    init(
        loadHomeFeedUseCase: LoadHomeFeedUseCase? = nil,
        userActivityRepository: (any UserActivityRepository)? = nil,
        fetchMyFavoritesUseCase: FetchMyFavoritesUseCase = FetchMyFavoritesUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        toggleFavoriteUseCase: ToggleFavoriteUseCase = ToggleFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        translateTextUseCase: TranslateTextUseCase? = nil,
        fetchUnreadNotificationCountUseCase: FetchUnreadNotificationCountUseCase = FetchUnreadNotificationCountUseCase(
            notificationRepository: DefaultNotificationRepository()
        )
    ) {
        let resolvedActivityRepository = userActivityRepository ?? LocalUserActivityRepository.shared
        self.userActivityRepository = resolvedActivityRepository
        self.loadHomeFeedUseCase = loadHomeFeedUseCase ?? LoadHomeFeedUseCase.live(
            userActivityRepository: resolvedActivityRepository
        )
        self.fetchMyFavoritesUseCase = fetchMyFavoritesUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.translateTextUseCase = translateTextUseCase ?? DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        )
        self.fetchUnreadNotificationCountUseCase = fetchUnreadNotificationCountUseCase
        observeFavoriteChanges()
        observeNotificationChanges()
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
        case .didTapFavorite(let gameId):
            toggleFavorite(gameId: gameId)
        case .didTapHomeFilter:
            onRoute?(.presentHomeFilterSheet(state.selectedFilter))
        case .didTapApplyHomeFilters(let filter):
            apply(.setSelectedFilter(filter))
            loadHomeData()
        case .didTapSeeMore(let section):
            routeToSectionList(section)
        case .didTapNotification:
            onRoute?(.showNotifications)
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
                async let feedTask = loadHomeFeedUseCase.execute(filter: state.selectedFilter)
                async let favoritesTask = fetchMyFavoritesUseCase.execute(sort: .latest)
                async let unreadCountTask = loadUnreadNotificationCount()
                let feed = try await feedTask
                let favoriteItems = (try? await favoritesTask) ?? []
                let unreadCount = (try? await unreadCountTask) ?? 0
                await MainActor.run {
                    self.apply(.setHomeFeed(feed))
                    self.apply(.setWishlistedGameIDs(Set(favoriteItems.map(\.gameId))))
                    self.apply(.setUnreadNotificationCount(unreadCount))
                    self.apply(.setLoading(false))
                }
            } catch {
                await MainActor.run {
                    self.apply(.setError(error.localizedDescription))
                }
            }
        }
    }

    private func loadUnreadNotificationCount() async throws -> Int {
        do {
            return try await fetchUnreadNotificationCountUseCase.execute()
        } catch let networkError as NetworkError {
            switch networkError {
            case .unauthorized:
                return 0
            default:
                throw networkError
            }
        } catch {
            throw error
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

    private func observeNotificationChanges() {
        NotificationCenter.default.publisher(for: .appNotificationsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let unreadCount = notification.userInfo?[AppNotificationChangeUserInfoKey.unreadCount] as? Int ?? 0
                self.apply(.setUnreadNotificationCount(unreadCount))
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

    private func toggleFavorite(gameId: Int) {
        let isCurrentlyFavorite = state.wishlistedGameIDs.contains(gameId)

        Task {
            do {
                let result = try await toggleFavoriteUseCase.execute(
                    gameId: String(gameId),
                    isCurrentlyFavorite: isCurrentlyFavorite
                )

                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .favoriteDidChange,
                        object: nil,
                        userInfo: [
                            FavoriteChangeUserInfoKey.gameId: result.gameId,
                            FavoriteChangeUserInfoKey.isFavorite: result.isFavorite,
                            FavoriteChangeUserInfoKey.action: result.isFavorite
                                ? FavoriteChangeAction.added.rawValue
                                : FavoriteChangeAction.removed.rawValue
                        ]
                    )
                }
            } catch {
                let favoriteError = FavoriteError.from(error: error)
                await MainActor.run {
                    self.apply(.setError(favoriteError.errorDescription ?? L10n.tr("Localizable", "favorite.error.updateFailed")))
                }
            }
        }
    }

    private func translateHomeFeed(_ feed: HomeFeed) async -> HomeFeed {
        feed
    }

    private func translateHighlights(_ highlights: [HomeHighlightItem]) async -> [HomeHighlightItem] {
        highlights
    }

    private func translateTodayRecommendations(_ recommendations: [TodayRecommendation]) async -> [TodayRecommendation] {
        recommendations
    }

    private func translateGames(
        _ games: [Game],
        context: String,
        translateSummary: Bool = false
    ) async -> [Game] {
        _ = context
        _ = translateSummary
        return games
    }
}

private extension Array where Element == Game {
    func deduplicatedGames() -> [Game] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}
