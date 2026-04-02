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
    private let fetchGameReviewsUseCase: FetchGameReviewsUseCase
    private let fetchFavoriteStatusUseCase: FetchFavoriteStatusUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let moderationRepository: any ModerationRepository
    private let languageProvider: any LanguageProviding
    private let translationProvider: any TranslationProviding
    private let translationCache: any TranslationCaching
    private let seedStore: GameDetailSeedStore

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
        languageProvider: any LanguageProviding = DefaultLanguageProvider.shared,
        translationProvider: any TranslationProviding = makeTranslationProvider(),
        translationCache: any TranslationCaching = DefaultTranslationCache.shared,
        seedStore: GameDetailSeedStore = .shared
    ) {
        self.apiClient = apiClient
        self.fetchGameReviewsUseCase = fetchGameReviewsUseCase
        self.fetchFavoriteStatusUseCase = fetchFavoriteStatusUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.moderationRepository = moderationRepository
        self.languageProvider = languageProvider
        self.translationProvider = translationProvider
        self.translationCache = translationCache
        self.seedStore = seedStore
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
        case .didTapTranslationToggle:
            guard state.hasTranslation else { return }
            apply(.setShowingTranslated(!state.isShowingTranslated))
        case .didReceiveTranslationResults(let results):
            handleTranslationResults(results)
        }
    }

    // MARK: - Private

    private func apply(_ mutation: GameDetailMutation) {
        state = GameDetailReducer.reduce(state, mutation)
    }

    private func loadDetail(gameId: Int) {
        apply(.clearError)
        apply(.setBlockingLoadError(nil))
        apply(.setInlineNotice(nil))

        if let seed = seedStore.seed(for: gameId) {
            let partialGame = seed.makePartialDetail()
            print(
                "[GameDetailSeed] " +
                "id=\(gameId) " +
                "source=\(seed.sourceDescription) " +
                "hasSummary=\(seed.summary?.isEmpty == false)"
            )
            apply(.setGame(partialGame))
        }

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
            let response = try await apiClient.request(
                .gameDetail(id: id),
                as: GameResponseEnvelopeDTO<GameDetailResponseDataDTO>.self
            )
            let entity = GameMapper.toDetailEntity(response.data.game)
            print("[GameDetail] success id=\(id) title=\(entity.title)")
            await MainActor.run {
                self.apply(.setGame(entity))
            }
            await prepareTranslation(for: entity)
        } catch {
            print("[GameDetail] failed id=\(id) error=\(error.localizedDescription)")
            let degradedMessage = temporaryDegradedMessage(for: error)
            let hasRenderableContent = await MainActor.run { self.state.hasRenderableContent }

            if let degradedMessage, hasRenderableContent {
                print(
                    "[GameDetailDegraded] " +
                    "id=\(id) " +
                    "temporary=true " +
                    "hasRenderableContent=true " +
                    "message=\(degradedMessage)"
                )
                await MainActor.run {
                    self.apply(.setInlineNotice(degradedMessage))
                    self.apply(.setBlockingLoadError(nil))
                    self.apply(.setLoading(false))
                }
                return
            }

            await MainActor.run {
                self.apply(.setBlockingLoadError(error.localizedDescription))
            }
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
                    self.apply(.setError(favoriteError.errorDescription ?? L10n.tr("Localizable", "favorite.error.updateFailed")))
                }
            }
        }
    }

    private func prepareTranslation(for game: GameDetail) async {
        let targetLanguage = languageProvider.currentLanguage
        let isSupported = translationProvider.supportsOnDeviceTranslation(
            targetLanguage: languageProvider.currentLanguageCode
        )
        print(
            "[TranslationAvailability] " +
            "iosVersion=\(currentOSVersionString()) " +
            "isSupported=\(isSupported)"
        )

        guard targetLanguage.isEnglish == false else {
            await MainActor.run {
                self.apply(.setTranslationLoading(false))
                self.apply(.setTranslationRequest(nil))
                self.apply(.setShowingTranslated(false))
            }
            return
        }

        let normalizedSummary = game.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoryline = game.storyline.trimmingCharacters(in: .whitespacesAndNewlines)
        let sharesSummaryText = normalizedSummary.isEmpty == false && normalizedSummary == normalizedStoryline

        let cachedSummary = normalizedSummary.isEmpty
            ? nil
            : translationCache.get(text: normalizedSummary, lang: targetLanguage)
        let cachedStoryline = normalizedStoryline.isEmpty
            ? nil
            : (sharesSummaryText
                ? cachedSummary
                : translationCache.get(text: normalizedStoryline, lang: targetLanguage))

        guard isSupported else {
            await MainActor.run {
                self.apply(.setTranslationLoading(false))
                self.apply(.setTranslationRequest(nil))
                self.apply(.setShowingTranslated(false))
            }
            return
        }

        let items = [
            !normalizedSummary.isEmpty && cachedSummary == nil
                ? TranslationRequestItem(identifier: String(game.id), field: "summary", text: normalizedSummary)
                : nil,
            !normalizedStoryline.isEmpty && !sharesSummaryText && cachedStoryline == nil
                ? TranslationRequestItem(identifier: String(game.id), field: "storyline", text: normalizedStoryline)
                : nil
        ].compactMap { $0 }

        items.forEach { item in
            print("[TranslationStart] textLength=\(item.text.count)")
        }

        let request = items.isEmpty
            ? nil
            : TranslationBatchRequest(
                context: "GameDetail",
                sourceLanguage: "en",
                targetLanguage: languageProvider.currentLanguageCode,
                items: items
            )

        await MainActor.run {
            self.apply(.setTranslatedFields(summary: cachedSummary, storyline: cachedStoryline))
            self.apply(.setShowingTranslated((cachedSummary?.isEmpty == false) || (cachedStoryline?.isEmpty == false)))
            self.apply(.setTranslationRequest(request))
            self.apply(.setTranslationLoading(request != nil))
        }
    }

    private func handleTranslationResults(_ results: [TranslationResultItem]) {
        guard let game = state.game else { return }
        let filteredResults = results.filter { $0.identifier == String(game.id) }

        guard !filteredResults.isEmpty else {
            apply(.setTranslationLoading(false))
            apply(.setTranslationRequest(nil))
            return
        }

        var translatedSummary: String?
        var translatedStoryline: String?

        for result in filteredResults {
            let normalizedTranslation = result.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedTranslation.isEmpty == false else { continue }

            translationCache.save(
                text: result.sourceText,
                lang: languageProvider.currentLanguage,
                translated: normalizedTranslation
            )
            print("[TranslationSuccess] translatedLength=\(normalizedTranslation.count)")

            switch result.field {
            case "summary":
                translatedSummary = normalizedTranslation
            case "storyline":
                translatedStoryline = normalizedTranslation
            default:
                break
            }
        }

        apply(.setTranslatedFields(summary: translatedSummary, storyline: translatedStoryline))
        apply(
            .setShowingTranslated(
                (translatedSummary?.isEmpty == false) ||
                (translatedStoryline?.isEmpty == false) ||
                state.hasTranslation
            )
        )
        apply(.setTranslationLoading(false))
        apply(.setTranslationRequest(nil))
    }

    private func currentOSVersionString() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    private func temporaryDegradedMessage(for error: Error) -> String? {
        guard let networkError = error as? NetworkError else { return nil }
        guard case let .serverError(statusCode, code, message) = networkError else { return nil }

        let normalizedCode = code?.uppercased() ?? ""
        let normalizedMessage = message?.lowercased() ?? ""
        let isIGDBTemporaryLimit = statusCode == 429
            || normalizedCode.contains("IGDB")
            || (normalizedMessage.contains("igdb") && normalizedMessage.contains("rate"))

        guard isIGDBTemporaryLimit else { return nil }
        return L10n.Detail.Notice.partialUnavailable
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
