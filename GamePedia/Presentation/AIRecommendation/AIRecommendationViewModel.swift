import Combine
import Foundation

final class AIRecommendationViewModel {
    private(set) var state: AIRecommendationState = AIRecommendationState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((AIRecommendationState) -> Void)?
    var onRouteToGameDetail: ((Int) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    private let fetchAIRecommendationsUseCase: any FetchAIRecommendationsUseCase
    private let fetchMyFavoritesUseCase: FetchMyFavoritesUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let librarySync: (any LibraryMutationSyncing)?
    private var currentRecommendationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var recommendationGamesById: [Int: Game] = [:]
    private var updatingFavoriteGameIds = Set<Int>()
    private var currentRecommendationToken: UUID?

    init(
        fetchAIRecommendationsUseCase: any FetchAIRecommendationsUseCase = DefaultFetchAIRecommendationsUseCase(),
        fetchMyFavoritesUseCase: FetchMyFavoritesUseCase = FetchMyFavoritesUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        toggleFavoriteUseCase: ToggleFavoriteUseCase = ToggleFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        librarySync: (any LibraryMutationSyncing)? = LibrarySyncRuntime.shared.mutationRouter
    ) {
        self.fetchAIRecommendationsUseCase = fetchAIRecommendationsUseCase
        self.fetchMyFavoritesUseCase = fetchMyFavoritesUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.librarySync = librarySync
        observeFavoriteChanges()
        observeLibrarySyncFailures()
        observePersonalizationInvalidationEvents()
    }

    deinit {
        currentRecommendationTask?.cancel()
    }

    func send(_ intent: AIRecommendationIntent) {
        switch intent {
        case .viewDidLoad:
            apply(.setExamples([
                L10n.tr("Localizable", "aiRecommendation.example.afterWorkHealing"),
                L10n.tr("Localizable", "aiRecommendation.example.withFriends"),
                L10n.tr("Localizable", "aiRecommendation.example.storyRPG"),
                L10n.tr("Localizable", "aiRecommendation.example.shortSession")
            ]))
            loadFavoriteStatus()
        case .queryChanged(let query):
            if state.isLoading, query != state.query {
                cancelInFlightRequest()
            }
            apply(.setQuery(query))
            if state.errorMessage != nil {
                apply(.setErrorMessage(nil))
            }
        case .exampleChipTapped(let example):
            apply(.setQuery(example))
            apply(.setErrorMessage(nil))
        case .recommendButtonTapped:
            fetchRecommendations()
        case .gameTapped(let gameId):
            if let game = recommendationGamesById[gameId] {
                GameDetailSeedStore.shared.store(games: [game], screen: "AIRecommendation.tap")
            }
            onRouteToGameDetail?(gameId)
        case .favoriteTapped(let gameId):
            toggleFavorite(gameId: gameId)
        case .retryTapped:
            fetchRecommendations()
        case .refreshTapped:
            fetchRecommendations()
        }
    }

    private func apply(_ mutation: AIRecommendationMutation) {
        state = AIRecommendationReducer.reduce(state, mutation)
    }

    private func fetchRecommendations() {
        guard state.isRecommendButtonEnabled else { return }

        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }
        currentRecommendationTask?.cancel()
        apply(.setLoading(true))
        apply(.setErrorMessage(nil))
        apply(.setHasRequestedRecommendations(true))
        let recommendationToken = UUID()
        currentRecommendationToken = recommendationToken

        currentRecommendationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await fetchAIRecommendationsUseCase.execute(query: query)
                let favoriteGameIds = await loadFavoriteGameIds()
                guard !Task.isCancelled else { return }
                let items = result.items.map { recommendation in
                    self.makeItemViewState(
                        from: recommendation,
                        isFavorite: favoriteGameIds.contains(recommendation.gameId)
                    )
                }
                let games = result.items.map(AIRecommendationMapper.toGame)

                await MainActor.run {
                    guard self.currentRecommendationToken == recommendationToken else { return }
                    self.currentRecommendationTask = nil
                    self.currentRecommendationToken = nil
                    self.recommendationGamesById = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
                    GameDetailSeedStore.shared.store(games: games, screen: "AIRecommendation.result")
                    self.apply(.setPersonalizationMetadata(
                        personalizationUsed: result.meta?.personalizationUsed,
                        personalizationAvailable: result.meta?.personalizationAvailable,
                        fallbackUsed: result.meta?.fallbackUsed,
                        recommendationSource: result.meta?.source,
                        generatedAt: result.meta?.generatedAt
                    ))
                    self.apply(.setRecommendations(items))
                    self.apply(.setDisclaimer(result.disclaimer))
                    self.apply(.setLoading(false))
#if DEBUG
                    print(
                        "[AIRecommendationRender] " +
                        "itemCount=\(items.count) " +
                        "visiblePersonalizedBadgeCount=\(items.filter(\.isPersonalized).count) " +
                        "staleState=\(self.state.isStale)"
                    )
#endif
                }
            } catch {
                guard !Task.isCancelled else { return }
                let recommendationError = AIRecommendationError.from(error: error)
                await MainActor.run {
                    guard self.currentRecommendationToken == recommendationToken else { return }
                    self.currentRecommendationTask = nil
                    self.currentRecommendationToken = nil
                    self.apply(.setLoading(false))

                    if recommendationError == .unauthorized {
                        self.onAuthenticationRequired?(.profile) { [weak self] in
                            self?.send(.recommendButtonTapped)
                        }
                        return
                    }

                    self.apply(.setErrorMessage(
                        recommendationError.errorDescription
                            ?? L10n.tr("Localizable", "aiRecommendation.error.default")
                    ))
                }
            }
        }
    }

    private func loadFavoriteStatus() {
        Task { [weak self] in
            guard let self else { return }
            let favoriteGameIds = await loadFavoriteGameIds()
            await MainActor.run {
                favoriteGameIds.forEach {
                    self.apply(.setFavorite(gameId: $0, isFavorite: true))
                }
            }
        }
    }

    private func loadFavoriteGameIds() async -> Set<Int> {
        do {
            let favorites = try await fetchMyFavoritesUseCase.execute(sort: .latest)
            return Set(favorites.map(\.gameId))
        } catch {
            return []
        }
    }

    private func toggleFavorite(gameId: Int) {
        guard !state.isLoading else { return }
        guard !updatingFavoriteGameIds.contains(gameId) else { return }

        let isCurrentlyFavorite = state.recommendations.first { $0.gameId == gameId }?.isFavorite ?? false

        // Authenticated route: gesture-time ownership is captured
        // synchronously HERE, before the submission Task exists, and the
        // intent is owned end-to-end by LibrarySyncEngine — this screen
        // never calls the favorite repository for an authenticated gesture.
        // The engine posts server-authoritative `.favoriteDidChange` on
        // success (already observed) and `.librarySyncOperationDidFail` on
        // permanent failure (observed in observeLibrarySyncFailures()).
        // Rapid gestures are ordered by the engine's gesture-time sequence
        // authority, so no per-item request lock is needed on this path.
        if let librarySync {
            if let ownership = librarySync.captureFavoriteIntent(
                gameID: String(gameId),
                isFavorite: !isCurrentlyFavorite
            ) {
                apply(.setFavorite(gameId: gameId, isFavorite: !isCurrentlyFavorite))
                Task { [weak self] in
                    guard let self else { return }
                    let result = await librarySync.enqueueFavoriteChange(
                        gameID: String(gameId),
                        isFavorite: !isCurrentlyFavorite,
                        ownership: ownership
                    )
                    switch result {
                    case .accepted, .staleOwnership, .supersededByNewerIntent:
                        // accepted: the engine owns delivery. stale/
                        // superseded: terminal — no networking, and neither
                        // the new account's UI nor a newer gesture's
                        // optimistic state may be touched.
                        break
                    case .storageBlocked, .serviceUnavailable:
                        // No second transport path: restore the last
                        // acknowledged state and surface a retryable
                        // failure. Guarded so a stale scope never touches
                        // the current account's UI and an old gesture never
                        // overwrites a newer one.
                        await MainActor.run {
                            guard librarySync.isNewestOwnedIntent(ownership) else { return }
                            self.apply(.setFavorite(gameId: gameId, isFavorite: isCurrentlyFavorite))
                            self.apply(.setErrorMessage(L10n.tr("Localizable", "favorite.error.updateFailed")))
                        }
                    }
                }
                return
            }
            // Guest gesture: the direct path can never attach a bearer
            // token (`.guestOnly`), so it deterministically fails
            // unauthorized and drives the existing auth gate — a login
            // racing the gesture cannot be mutated.
            performDirectFavoriteToggle(
                gameId: gameId,
                isCurrentlyFavorite: isCurrentlyFavorite,
                authorization: .guestOnly
            )
            return
        }

        // Offline-sync kill-switch (compile-time unreachable while the
        // feature flag is on): the pre-2.2 legacy behavior.
        performDirectFavoriteToggle(
            gameId: gameId,
            isCurrentlyFavorite: isCurrentlyFavorite,
            authorization: .currentSession
        )
    }

    private func performDirectFavoriteToggle(
        gameId: Int,
        isCurrentlyFavorite: Bool,
        authorization: RequestAuthorization
    ) {
        updatingFavoriteGameIds.insert(gameId)
        apply(.setFavorite(gameId: gameId, isFavorite: !isCurrentlyFavorite))
        apply(.setFavoriteUpdating(gameId: gameId, isUpdating: true))

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await toggleFavoriteUseCase.execute(
                    gameId: String(gameId),
                    isCurrentlyFavorite: isCurrentlyFavorite,
                    authorization: authorization
                )

                await MainActor.run {
                    self.updatingFavoriteGameIds.remove(gameId)
                    self.apply(.setFavoriteUpdating(gameId: gameId, isUpdating: false))
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
                    self.updatingFavoriteGameIds.remove(gameId)
                    self.apply(.setFavorite(gameId: gameId, isFavorite: isCurrentlyFavorite))
                    self.apply(.setFavoriteUpdating(gameId: gameId, isUpdating: false))

                    if favoriteError == .unauthorized {
                        self.onAuthenticationRequired?(.profile) { [weak self] in
                            self?.send(.favoriteTapped(gameId: gameId))
                        }
                        return
                    }

                    self.apply(.setErrorMessage(
                        favoriteError.errorDescription
                            ?? L10n.tr("Localizable", "favorite.error.updateFailed")
                    ))
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

                self.apply(.setFavorite(gameId: gameId, isFavorite: isFavorite))
                self.markRecommendationsStale(reason: "favoriteDidChange")
            }
            .store(in: &cancellables)
    }

    /// A queued favorite change permanently failed after the optimistic
    /// flip: reconcile against the failed operation's intended state (never
    /// by inverting whatever is on screen) and surface the failure. A newer
    /// queued intent supersedes the failure entirely.
    private func observeLibrarySyncFailures() {
        NotificationCenter.default.publisher(for: .librarySyncOperationDidFail)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let kind = notification.userInfo?[LibrarySyncFailureUserInfoKey.entityKind] as? String,
                      kind == LibrarySyncEntityKind.favorite.rawValue,
                      let failedGameID = notification.userInfo?[LibrarySyncFailureUserInfoKey.gameID] as? String,
                      let gameId = Int(failedGameID),
                      let intended = notification
                        .userInfo?[LibrarySyncFailureUserInfoKey.intendedIsFavorite] as? Bool,
                      self.state.recommendations.contains(where: { $0.gameId == gameId }) else {
                    return
                }
                let superseded = notification
                    .userInfo?[LibrarySyncFailureUserInfoKey.supersededByNewerIntent] as? Bool ?? false
                guard superseded == false else { return }
                self.apply(.setFavorite(gameId: gameId, isFavorite: !intended))
                self.apply(.setErrorMessage(L10n.tr("Localizable", "favorite.error.updateFailed")))
            }
            .store(in: &cancellables)
    }

    private func observePersonalizationInvalidationEvents() {
        let notificationNames: [Notification.Name] = [
            .reviewDidChange,
            .libraryDidChange,
            .authSessionDidChange,
            .currentUserProfileDidChange,
            .steamLinkDidComplete,
            .steamLinkStateDidChange
        ]

        notificationNames.forEach { name in
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    self?.markRecommendationsStale(reason: notification.name.rawValue)
                }
                .store(in: &cancellables)
        }
    }

    private func markRecommendationsStale(reason: String) {
        let hasQuery = !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasQuery, state.hasRequestedRecommendations, !state.recommendations.isEmpty else { return }
        apply(.setStale(true))
#if DEBUG
        print("[AIRecommendation] stale reason=\(reason) queryLength=\(state.query.count)")
#endif
    }

    private func makeItemViewState(
        from recommendation: AIRecommendation,
        isFavorite: Bool
    ) -> AIRecommendationItemViewState {
        let ratingText: String
        if let rating = recommendation.rating {
            ratingText = GameRatingDisplayFormatter.makeDisplay(
                userRating: rating,
                aggregatedRating: nil,
                totalRating: nil
            ).displayText ?? "—"
        } else {
            ratingText = "—"
        }

        let recommendationReasonTags = makeRecommendationReasonTags(from: recommendation)
        let rawDisplayTagInputs = recommendationReasonTags
            + recommendation.reasonTags
            + recommendation.intentTags
            + recommendation.matchTags
            + recommendation.rawMatchTags
            + recommendation.displayTags
            + recommendation.canonicalTags
        let displayTags = RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: rawDisplayTagInputs,
            genres: recommendation.genres,
            themes: recommendation.themes,
            keywords: recommendation.keywords,
            maxCount: 3,
            screen: "AIRecommendation"
        )
        let unknownFallbackCount = RecommendationTagLocalizer.unknownFallbackCount(
            for: rawDisplayTagInputs + recommendation.genres + recommendation.themes + recommendation.keywords
        )

#if DEBUG
        print(
            "[AIRecommendationTags] localized " +
            "gameId=\(recommendation.gameId) " +
            "rawTagCount=\(rawDisplayTagInputs.count) " +
            "displayTagCount=\(displayTags.count) " +
            "unknownFallbackCount=\(unknownFallbackCount)"
        )
#endif

        return AIRecommendationItemViewState(
            gameId: recommendation.gameId,
            title: recommendation.title,
            coverURL: recommendation.coverURL,
            platforms: recommendation.platforms,
            genres: recommendation.genres,
            ratingText: ratingText,
            reason: recommendation.reason,
            matchTags: recommendation.matchTags,
            displayTags: displayTags,
            confidence: recommendation.confidence,
            isPersonalized: recommendation.personalized,
            isFallback: recommendation.fallbackUsed,
            confidenceText: nil,
            isFavorite: isFavorite,
            isFavoriteUpdating: false
        )
    }

    private func makeRecommendationReasonTags(from recommendation: AIRecommendation) -> [String] {
        var tags: [String] = []
        if recommendation.personalized {
            tags.append("personalized")
        }
        if recommendation.fallbackUsed {
            tags.append("default ranking")
        }
        if let source = recommendation.recommendationSource?.lowercased(),
           source.contains("fallback") || source.contains("default") {
            tags.append("default ranking")
        }
        return tags
    }

    func cancelInFlightRequest() {
        currentRecommendationTask?.cancel()
        currentRecommendationTask = nil
        currentRecommendationToken = nil
        if state.isLoading {
            apply(.setLoading(false))
        }
    }
}
