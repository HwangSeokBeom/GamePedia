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

enum LibraryHighlightChip: Int {
    case recentlyPlayed = 0
    case reviewed = 1
    case playtimeRecommendations = 2

    var focusedSection: LibrarySectionKind {
        switch self {
        case .recentlyPlayed:
            return .recentlyPlayed
        case .reviewed:
            return .reviewed
        case .playtimeRecommendations:
            return .playtimeRecommendations
        }
    }
}

enum LibraryRecentlyPlayedSource: Hashable {
    case none
    case snapshot
    case full
}

enum LibrarySummaryPrimaryValueKind: String, Codable, Hashable {
    case hours
    case count
}

struct LibraryTabSummaryState: Hashable {
    let primaryTitle: String
    let primaryValue: Double
    let primaryValueKind: LibrarySummaryPrimaryValueKind
    let averageRating: Double?
    let gameCount: Int
    let reviewCount: Int
    let sourceDescription: String

    static func empty(for tab: LibraryTab) -> LibraryTabSummaryState {
        switch tab {
        case .playing:
            return LibraryTabSummaryState(
                primaryTitle: L10n.Library.Summary.totalPlay,
                primaryValue: 0,
                primaryValueKind: .hours,
                averageRating: nil,
                gameCount: 0,
                reviewCount: 0,
                sourceDescription: "empty"
            )
        case .favorites:
            return LibraryTabSummaryState(
                primaryTitle: L10n.Library.Summary.wishlist,
                primaryValue: 0,
                primaryValueKind: .count,
                averageRating: nil,
                gameCount: 0,
                reviewCount: 0,
                sourceDescription: "empty"
            )
        case .reviewed:
            return LibraryTabSummaryState(
                primaryTitle: L10n.Library.Summary.reviewed,
                primaryValue: 0,
                primaryValueKind: .count,
                averageRating: nil,
                gameCount: 0,
                reviewCount: 0,
                sourceDescription: "empty"
            )
        }
    }

    static var defaultsByTab: [LibraryTab: LibraryTabSummaryState] {
        [
            .playing: .empty(for: .playing),
            .favorites: .empty(for: .favorites),
            .reviewed: .empty(for: .reviewed)
        ]
    }
}

struct LibraryState: Equatable {
    var selectedTab: LibraryTab = .playing
    var selectedHighlightChip: LibraryHighlightChip = .recentlyPlayed
    var selectedSort: LibrarySortOption = .latest
    var summaryByTab: [LibraryTab: LibraryTabSummaryState] = LibraryTabSummaryState.defaultsByTab
    var serverSummaryByTab: [LibraryTab: LibraryServerSummary] = [:]
    var previewGeneratedAt: Date? = nil
    var fullGeneratedAt: Date? = nil
    var mergedGeneratedAt: Date? = nil
    var recentlyPlayedSource: LibraryRecentlyPlayedSource = .none
    var steamLinkStatus: SteamLinkStatus = .notLinked
    var isSteamConnected: Bool = false
    var steamSyncStatus: SteamSyncStatus = .idle
    var isSteamSyncAvailable: Bool = true
    var steamSyncErrorCode: String? = nil
    var recentlyPlayed: [LibraryGameSummary] = []
    var playingGames: [LibraryGameSummary] = []
    var ownedGames: [LibraryGameSummary] = []
    var backlogGames: [LibraryGameSummary] = []
    var playtimeRecommendations: [PlaytimeRecommendation] = []
    var friendRecommendations: [SteamFriendRecommendation] = []
    var friendRecommendationsSource: LibraryFriendRecommendationSource = .none
    var friendRecommendationsEmptyState: LibraryFriendRecommendationsEmptyState? = nil
    var likedGames: [Game] = []
    var reviews: [ReviewedGame] = []
    var steamOwnedSyncErrorCode: String? = nil
    var addingToPlayingIdentifiers: Set<LibraryGameIdentifier> = []
    var isSyncingOwnedSteamLibrary: Bool = false
    var isUnlinkingSteamAccount: Bool = false
    var sections: [LibrarySectionViewState] = []
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var isSummaryLoading: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var steamConnectionOnboarding: LibraryOnboardingViewState? = nil
    var pendingFocusSection: LibrarySectionKind? = nil
}

struct LibraryOnboardingViewState: Equatable {
    let title: String
    let message: String
    let helperText: String?
}
