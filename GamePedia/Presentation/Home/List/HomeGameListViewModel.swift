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
        applyFavoriteChange(gameId: gameId, isFavorite: !isCurrentlyFavorite)

        // Offline-first path: accept locally; the engine posts the
        // server-authoritative `.favoriteDidChange` on success and
        // `.librarySyncOperationDidFail` on permanent failure.
        if let librarySync {
            Task {
                let accepted = await librarySync.enqueueFavoriteChange(
                    gameID: String(gameId),
                    isFavorite: !isCurrentlyFavorite
                )
                if !accepted {
                    await self.performDirectFavoriteToggle(
                        gameId: gameId,
                        isCurrentlyFavorite: isCurrentlyFavorite
                    )
                }
            }
            return
        }

        Task {
            await performDirectFavoriteToggle(gameId: gameId, isCurrentlyFavorite: isCurrentlyFavorite)
        }
    }

    private func performDirectFavoriteToggle(gameId: Int, isCurrentlyFavorite: Bool) async {
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
                await MainActor.run {
                    self.applyFavoriteChange(gameId: gameId, isFavorite: isCurrentlyFavorite)
                }
                print("[HomeGameList] favoriteToggleFailed gameId=\(gameId) error=\(error.localizedDescription)")
            }
    }

    /// A queued favorite change permanently failed after the optimistic
    /// update: revert that game's local entry.
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
                let isCurrentlyMarked = self.state.wishlistedGameIDs.contains(gameId)
                self.applyFavoriteChange(gameId: gameId, isFavorite: !isCurrentlyMarked)
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
