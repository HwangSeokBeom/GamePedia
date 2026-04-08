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
    private var cancellables = Set<AnyCancellable>()

    init(
        section: HomeSection,
        games: [Game],
        wishlistedGameIDs: Set<Int>,
        toggleFavoriteUseCase: ToggleFavoriteUseCase = ToggleFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        )
    ) {
        self.state = HomeGameListState(
            section: section,
            games: games,
            wishlistedGameIDs: wishlistedGameIDs
        )
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        observeFavoriteChanges()
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
                await MainActor.run {
                    self.applyFavoriteChange(gameId: gameId, isFavorite: isCurrentlyFavorite)
                }
                print("[HomeGameList] favoriteToggleFailed gameId=\(gameId) error=\(error.localizedDescription)")
            }
        }
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
