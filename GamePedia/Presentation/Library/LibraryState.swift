import Foundation

enum LibraryTab: Int {
    case playing = 0
    case favorites = 1
    case reviewed = 2

    var focusedSection: LibrarySectionKind {
        switch self {
        case .playing:
            return .playing
        case .favorites:
            return .wishlist
        case .reviewed:
            return .reviewed
        }
    }
}

enum LibrarySortOption: Int {
    case latest = 0
    case oldest = 1

    var favoriteSort: FavoriteSortOption {
        self == .oldest ? .oldest : .latest
    }

    var reviewSort: ReviewSortOption {
        self == .oldest ? .oldest : .latest
    }

    var userGameSort: UserGameCollectionSortOption {
        self == .oldest ? .oldest : .latest
    }
}

struct LibraryState {
    var selectedSort: LibrarySortOption = .latest
    var isSteamConnected: Bool = true
    var isSteamSyncAvailable: Bool = true
    var steamSyncErrorCode: String? = nil
    var recentlyPlayed: [LibraryGameSummary] = []
    var playingGames: [LibraryGameSummary] = []
    var ownedGames: [LibraryGameSummary] = []
    var backlogGames: [LibraryGameSummary] = []
    var likedGames: [Game] = []
    var reviews: [ReviewedGame] = []
    var addingToPlayingIdentifiers: Set<LibraryGameIdentifier> = []
    var isSyncingOwnedSteamLibrary: Bool = false
    var sections: [LibrarySectionViewState] = []
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var pendingFocusSection: LibrarySectionKind? = nil
}
