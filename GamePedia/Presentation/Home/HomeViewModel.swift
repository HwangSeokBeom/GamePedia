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
    private let librarySync: (any LibraryMutationSyncing)?
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
        ),
        librarySync: (any LibraryMutationSyncing)? = LibrarySyncRuntime.shared.mutationRouter
    ) {
        self.librarySync = librarySync
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
        observeLibrarySyncFailures()
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

        // Offline-first path: ownership (account scope + gesture sequence)
        // is captured synchronously HERE, before the submission Task exists,
        // so a later account switch can never re-bind the intent and a later
        // gesture can never be reordered behind this one. The engine posts
        // server-authoritative `.favoriteDidChange` on success (already
        // observed) and `.librarySyncOperationDidFail` on permanent failure
        // (observed below), which re-syncs this screen.
        if let librarySync {
            let ownership = librarySync.captureFavoriteIntent(
                gameID: String(gameId),
                isFavorite: !isCurrentlyFavorite
            )
            var updatedIDs = state.wishlistedGameIDs
            if isCurrentlyFavorite {
                updatedIDs.remove(gameId)
            } else {
                updatedIDs.insert(gameId)
            }
            apply(.setWishlistedGameIDs(updatedIDs))

            Task {
                guard let ownership else {
                    // No authenticated account owned the gesture: the
                    // pre-2.2 direct path applies unchanged.
                    await self.performDirectFavoriteToggle(
                        gameId: gameId,
                        isCurrentlyFavorite: isCurrentlyFavorite
                    )
                    return
                }
                let result = await librarySync.enqueueFavoriteChange(
                    gameID: String(gameId),
                    isFavorite: !isCurrentlyFavorite,
                    ownership: ownership
                )
                switch result {
                case .accepted, .staleOwnership, .supersededByNewerIntent:
                    // accepted: the engine owns delivery. stale/superseded:
                    // the owning scope ended or a newer gesture governs —
                    // the direct path must never run for this intent.
                    break
                case .storageBlocked, .serviceUnavailable:
                    await self.performCoordinatedDirectFavoriteToggle(
                        gameId: gameId,
                        isCurrentlyFavorite: isCurrentlyFavorite,
                        ownership: ownership,
                        librarySync: librarySync
                    )
                }
            }
            return
        }

        Task {
            await performDirectFavoriteToggle(
                gameId: gameId,
                isCurrentlyFavorite: isCurrentlyFavorite
            )
        }
    }

    /// Guest / kill-switch direct path (pre-2.2), unchanged: no ownership
    /// context exists, so there is no authenticated scope to adjudicate.
    private func performDirectFavoriteToggle(
        gameId: Int,
        isCurrentlyFavorite: Bool
    ) async {
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

    /// Authenticated engine fallback (`.storageBlocked` /
    /// `.serviceUnavailable` only): the shared coordinator is the only path
    /// to the repository. It suppresses out-of-order gesture sequences,
    /// serializes requests per (scope, entity) — across every ViewModel —
    /// and revalidates scope ownership immediately before the request is
    /// constructed and again before this outcome applies.
    private func performCoordinatedDirectFavoriteToggle(
        gameId: Int,
        isCurrentlyFavorite: Bool,
        ownership: LibraryMutationOwnership,
        librarySync: any LibraryMutationSyncing
    ) async {
        let useCase = toggleFavoriteUseCase
        await librarySync.runAuthenticatedDirectFallback(
            ownership: ownership,
            operation: {
                try await useCase.execute(
                    gameId: String(gameId),
                    isCurrentlyFavorite: isCurrentlyFavorite
                )
            },
            apply: { outcome in
                await MainActor.run {
                    // A completion from a scope that ended mid-request must
                    // not touch the current account's UI.
                    guard self.librarySync?.isOwnershipCurrent(ownership) == true else { return }
                    switch outcome {
                    case .success(let result):
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
                    case .failure(let error):
                        let favoriteError = FavoriteError.from(error: error)
                        self.apply(.setError(favoriteError.errorDescription ?? L10n.tr("Localizable", "favorite.error.updateFailed")))
                    case .suppressed:
                        // A newer gesture governs this entity (or the scope
                        // ended); the newest intent posts its own outcome.
                        break
                    }
                }
            }
        )
    }

    /// A queued favorite change permanently failed after the optimistic
    /// wishlist update: revert that game's local entry and surface an error.
    private func observeLibrarySyncFailures() {
        NotificationCenter.default.publisher(for: .librarySyncOperationDidFail)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let kind = notification.userInfo?[LibrarySyncFailureUserInfoKey.entityKind] as? String,
                      kind == LibrarySyncEntityKind.favorite.rawValue,
                      let failedGameID = notification.userInfo?[LibrarySyncFailureUserInfoKey.gameID] as? String,
                      let gameId = Int(failedGameID) else {
                    return
                }
                // A newer queued intent for this game still governs the UI;
                // this failure is history and must not touch state.
                let superseded = notification
                    .userInfo?[LibrarySyncFailureUserInfoKey.supersededByNewerIntent] as? Bool ?? false
                guard superseded == false else { return }
                // Reconcile against the failed operation's intended state —
                // never by inverting whatever is currently on screen.
                if let intended = notification
                    .userInfo?[LibrarySyncFailureUserInfoKey.intendedIsFavorite] as? Bool {
                    var updatedIDs = self.state.wishlistedGameIDs
                    if intended {
                        updatedIDs.remove(gameId)
                    } else {
                        updatedIDs.insert(gameId)
                    }
                    self.apply(.setWishlistedGameIDs(updatedIDs))
                }
                self.apply(.setError(L10n.tr("Localizable", "favorite.error.updateFailed")))
            }
            .store(in: &cancellables)
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
