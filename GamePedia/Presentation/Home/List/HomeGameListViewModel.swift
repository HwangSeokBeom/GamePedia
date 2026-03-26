import Combine
import Foundation

enum HomeGameListIntent {
    case viewDidLoad
}

final class HomeGameListViewModel {

    private(set) var state: HomeGameListState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((HomeGameListState) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init(section: HomeSection, games: [Game], wishlistedGameIDs: Set<Int>) {
        self.state = HomeGameListState(
            section: section,
            games: games,
            wishlistedGameIDs: wishlistedGameIDs
        )
        observeFavoriteChanges()
    }

    func send(_ intent: HomeGameListIntent) {
        switch intent {
        case .viewDidLoad:
            onStateChanged?(state)
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
}
