import Foundation

// MARK: - GameDetailViewModel

final class GameDetailViewModel {

    // MARK: State
    private(set) var state: GameDetailState = GameDetailState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((GameDetailState) -> Void)?

    // MARK: Navigation Events — handled by ViewController
    var onWriteReview: ((GameDetail, Review?) -> Void)?
    var onShowAllReviews: ((GameDetail) -> Void)?
    var onShare: ((GameDetail) -> Void)?

    // MARK: Dependencies
    private let apiClient: APIClient
    private let translateTextUseCase: TranslateTextUseCase
    private let fetchGameReviewsUseCase: FetchGameReviewsUseCase
    private let fetchFavoriteStatusUseCase: FetchFavoriteStatusUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let moderationRepository: any ModerationRepository

    // MARK: Init
    init(
        apiClient: APIClient = .shared,
        fetchGameReviewsUseCase: FetchGameReviewsUseCase = FetchGameReviewsUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        fetchFavoriteStatusUseCase: FetchFavoriteStatusUseCase = FetchFavoriteStatusUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        toggleFavoriteUseCase: ToggleFavoriteUseCase = ToggleFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        moderationRepository: any ModerationRepository = DefaultModerationRepository(),
        translateTextUseCase: TranslateTextUseCase? = nil
    ) {
        self.apiClient = apiClient
        self.fetchGameReviewsUseCase = fetchGameReviewsUseCase
        self.fetchFavoriteStatusUseCase = fetchFavoriteStatusUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.moderationRepository = moderationRepository
        self.translateTextUseCase = translateTextUseCase ?? DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        )
    }

    // MARK: - Intent Processing

    func send(_ intent: GameDetailIntent) {
        switch intent {
        case .viewDidLoad(let id):
            loadDetail(gameId: id)
        case .didTapHaveIt:
            toggleFavorite()
        case .didTapWriteReview:
            guard let game = state.game else { return }
            onWriteReview?(game, state.myReview)
        case .didTapShare:
            guard let game = state.game else { return }
            onShare?(game)
        case .didTapSeeAllReviews:
            guard let game = state.game else { return }
            onShowAllReviews?(game)
        }
    }

    // MARK: - Private

    private func apply(_ mutation: GameDetailMutation) {
        state = GameDetailReducer.reduce(state, mutation)
    }

    private func loadDetail(gameId: Int) {
        apply(.setLoading(true))

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchGame(id: gameId) }
                group.addTask { await self.fetchReviews(gameId: gameId) }
                group.addTask { await self.fetchFavoriteStatus(gameId: gameId) }
            }
        }
    }

    private func fetchGame(id: Int) async {
        do {
            // IGDB returns an array even for single-item queries
            let dtos = try await apiClient.request(.gameDetail(id: id), as: [IGDBGameDetailDTO].self)
            guard let dto = dtos.first else {
                await MainActor.run { self.apply(.setError("게임 정보를 찾을 수 없습니다.")) }
                return
            }
            let entity = IGDBGameMapper.toDetailEntity(dto)
            let translatedEntity = await translateGame(entity)
            await MainActor.run {
                self.apply(.setGame(translatedEntity))
            }
        } catch {
            await MainActor.run { self.apply(.setError(error.localizedDescription)) }
        }
    }

    private func fetchReviews(gameId: Int) async {
        do {
            let reviewFeed = try await fetchGameReviewsUseCase.execute(
                gameId: String(gameId),
                sort: .latest
            )
            await MainActor.run {
                let visibleReviews = self.visibleReviews(from: reviewFeed.reviews)
                self.apply(
                    .setReviewFeed(
                        GameReviewFeed(
                            reviews: visibleReviews,
                            summary: self.makeReviewSummary(from: visibleReviews)
                        )
                    )
                )
            }
        } catch {
            // Reviews failing silently — detail still shows
        }
    }

    private func fetchFavoriteStatus(gameId: Int) async {
        do {
            let favoriteStatus = try await fetchFavoriteStatusUseCase.execute(gameId: String(gameId))
            await MainActor.run {
                self.apply(.setFavorite(favoriteStatus.isFavorite))
            }
        } catch {
            // Favorite status should not block detail rendering.
        }
    }

    private func toggleFavorite() {
        guard let game = state.game, !state.isFavoriteLoading else { return }

        apply(.setFavoriteLoading(true))

        Task {
            do {
                let result = try await toggleFavoriteUseCase.execute(
                    gameId: String(game.id),
                    isCurrentlyFavorite: state.isFavorite
                )

                await MainActor.run {
                    self.apply(.setFavorite(result.isFavorite))
                    self.apply(.setFavoriteLoading(false))
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
                    self.apply(.setFavoriteLoading(false))
                    self.apply(.setError(favoriteError.errorDescription ?? "찜 상태를 변경하지 못했습니다."))
                }
            }
        }
    }

    private func translateGame(_ game: GameDetail) async -> GameDetail {
        let normalizedSummary = game.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoryline = game.storyline.trimmingCharacters(in: .whitespacesAndNewlines)
        let sharesSummaryText = normalizedSummary == normalizedStoryline

        let items = [
            game.translatedTitle == nil
                ? TranslationRequestItem(identifier: String(game.id), field: "title", text: game.title)
                : nil,
            !normalizedSummary.isEmpty
                ? TranslationRequestItem(identifier: String(game.id), field: "summary", text: game.summary)
                : nil,
            !normalizedStoryline.isEmpty && !sharesSummaryText
                ? TranslationRequestItem(identifier: String(game.id), field: "storyline", text: game.storyline)
                : nil
        ].compactMap { $0 }

        guard !items.isEmpty else { return game }

        let results = await translateTextUseCase.execute(
            items: items,
            context: "GameDetail",
            sourceLanguage: "en"
        )
        let translatedValues = Dictionary(uniqueKeysWithValues: results.map { ($0.field, $0.translatedText) })
        let translatedSummary = translatedValues["summary"]
        let translatedStoryline = translatedValues["storyline"] ?? (sharesSummaryText ? translatedSummary : nil)

        return game.replacingTranslated(
            translatedTitle: translatedValues["title"],
            translatedSummary: translatedSummary,
            translatedStoryline: translatedStoryline
        )
    }

    private func visibleReviews(from reviews: [Review]) -> [Review] {
        let hiddenReviewIDs = moderationRepository.hiddenReviewIDs()
        let blockedUserIDs = moderationRepository.blockedUserIDs()

        return reviews.filter { review in
            !hiddenReviewIDs.contains(review.id) && !blockedUserIDs.contains(review.author.id)
        }
    }

    private func makeReviewSummary(from reviews: [Review]) -> ReviewSummary {
        guard !reviews.isEmpty else {
            return ReviewSummary(reviewCount: 0, averageRating: nil)
        }

        let averageRating = reviews.reduce(0.0) { partialResult, review in
            partialResult + review.rating
        } / Double(reviews.count)

        return ReviewSummary(
            reviewCount: reviews.count,
            averageRating: (averageRating * 10).rounded() / 10
        )
    }
}
