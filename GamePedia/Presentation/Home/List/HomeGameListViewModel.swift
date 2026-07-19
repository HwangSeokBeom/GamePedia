import Combine
import Foundation

enum HomeGameListIntent {
    case viewDidLoad
    case didTapFavorite(gameId: Int)
}

final class HomeGameListViewModel {

    private(set) var state: HomeGameListState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((HomeGameListState) -> Void)?
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let librarySync: (any LibraryMutationSyncing)?
    private var cancellables = Set<AnyCancellable>()

    init(
        section: HomeSection,
        games: [Game],
        wishlistedGameIDs: Set<Int>,
        toggleFavoriteUseCase: ToggleFavoriteUseCase = ToggleFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        librarySync: (any LibraryMutationSyncing)? = LibrarySyncRuntime.shared.mutationRouter
    ) {
        self.state = HomeGameListState(
            section: section,
            games: games,
            wishlistedGameIDs: wishlistedGameIDs
        )
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.librarySync = librarySync
        observeFavoriteChanges()
        observeLibrarySyncFailures()
    }

    func send(_ intent: HomeGameListIntent) {
        switch intent {
        case .viewDidLoad:
            onStateChanged?(state)
        case .didTapFavorite(let gameId):
            toggleFavorite(gameId: gameId)
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

                self.state = HomeGameListState(
                    section: self.state.section,
                    games: self.state.games,
                    wishlistedGameIDs: updatedIDs
                )
            }
            .store(in: &cancellables)
    }

    private func toggleFavorite(gameId: Int) {
        let isCurrentlyFavorite = state.wishlistedGameIDs.contains(gameId)

        // Offline-first path: ownership (account scope + gesture sequence)
        // is captured synchronously HERE, before the optimistic flip and the
        // submission Task, so a later account switch can never re-bind the
        // intent and rapid gestures keep their true order. The engine posts
        // the server-authoritative `.favoriteDidChange` on success and
        // `.librarySyncOperationDidFail` on permanent failure.
        if let librarySync {
            let ownership = librarySync.captureFavoriteIntent(
                gameID: String(gameId),
                isFavorite: !isCurrentlyFavorite
            )
            applyFavoriteChange(gameId: gameId, isFavorite: !isCurrentlyFavorite)
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
                    // this intent is terminal and must never touch the
                    // network or newer UI state.
                    break
                case .storageBlocked, .serviceUnavailable:
                    // The engine could not durably own the intent. No second
                    // transport path: reconcile the optimistic flip to the
                    // last acknowledged state (retryable — the user can tap
                    // again). Guarded so a stale scope never touches the
                    // current account's UI and an old gesture never
                    // overwrites a newer one.
                    await MainActor.run {
                        guard librarySync.isNewestOwnedIntent(ownership) else { return }
                        self.applyFavoriteChange(gameId: gameId, isFavorite: isCurrentlyFavorite)
                        print("[HomeGameList] favoriteIntentRefused gameId=\(gameId) result=\(result)")
                    }
                }
            }
            return
        }

        applyFavoriteChange(gameId: gameId, isFavorite: !isCurrentlyFavorite)
        Task {
            await performDirectFavoriteToggle(
                gameId: gameId,
                isCurrentlyFavorite: isCurrentlyFavorite,
                authorization: .currentSession
            )
        }
    }

    /// Direct path for gestures the engine does not own. `.guestOnly` for
    /// guest gestures (can never attach a bearer token, so a login racing
    /// the gesture cannot be mutated); `.currentSession` only for the
    /// explicit offline-sync kill-switch (librarySync == nil).
    private func performDirectFavoriteToggle(
        gameId: Int,
        isCurrentlyFavorite: Bool,
        authorization: RequestAuthorization = .guestOnly
    ) async {
            do {
                let result = try await toggleFavoriteUseCase.execute(
                    gameId: String(gameId),
                    isCurrentlyFavorite: isCurrentlyFavorite,
                    authorization: authorization
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
                await MainActor.run {
                    self.applyFavoriteChange(gameId: gameId, isFavorite: isCurrentlyFavorite)
                }
                print("[HomeGameList] favoriteToggleFailed gameId=\(gameId) error=\(error.localizedDescription)")
            }
    }

    /// A queued favorite change permanently failed after the optimistic
    /// update: revert that game's local entry to the pre-intent state.
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
                        .userInfo?[LibrarySyncFailureUserInfoKey.intendedIsFavorite] as? Bool else {
                    return
                }
                // A newer queued intent for this game still governs the UI;
                // an old failure must not invert the newest state.
                let superseded = notification
                    .userInfo?[LibrarySyncFailureUserInfoKey.supersededByNewerIntent] as? Bool ?? false
                guard superseded == false else { return }
                self.applyFavoriteChange(gameId: gameId, isFavorite: !intended)
            }
            .store(in: &cancellables)
    }

    private func applyFavoriteChange(gameId: Int, isFavorite: Bool) {
        var updatedIDs = state.wishlistedGameIDs
        if isFavorite {
            updatedIDs.insert(gameId)
        } else {
            updatedIDs.remove(gameId)
        }

        state = HomeGameListState(
            section: state.section,
            games: state.games,
            wishlistedGameIDs: updatedIDs
        )
    }
}
