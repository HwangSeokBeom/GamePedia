import Foundation

enum HomeGameListIntent {
    case viewDidLoad
}

final class HomeGameListViewModel {

    private(set) var state: HomeGameListState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((HomeGameListState) -> Void)?

    init(section: HomeSection, games: [Game], wishlistedGameIDs: Set<Int>) {
        self.state = HomeGameListState(
            section: section,
            games: games,
            wishlistedGameIDs: wishlistedGameIDs
        )
    }

    func send(_ intent: HomeGameListIntent) {
        switch intent {
        case .viewDidLoad:
            onStateChanged?(state)
        }
    }
}
