import Foundation

enum LibraryMutation {
    case setLoading(Bool)
    case setRefreshing(Bool)
    case setSummaryLoading(Bool)
    case setSelectedTab(LibraryTab)
    case setSelectedHighlightChip(LibraryHighlightChip)
    case setSort(LibrarySortOption)
    case setSummaryByTab([LibraryTab: LibraryTabSummaryState])
    case setServerSummaryByTab([LibraryTab: LibraryServerSummary])
    case setPreviewGeneratedAt(Date?)
    case setFullGeneratedAt(Date?)
    case setMergedRecentlyPlayedState(LibraryRecentlyPlayedSource, Date?)
    case setSteamState(
        steamLinkStatus: SteamLinkStatus,
        isConnected: Bool,
        syncStatus: SteamSyncStatus,
        isSyncAvailable: Bool,
        errorCode: String?
    )
    case setLibraryItems(
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        ownedGames: [LibraryGameSummary],
        backlogGames: [LibraryGameSummary],
        likedGames: [Game],
        reviews: [ReviewedGame]
    )
    case setPlaytimeRecommendations([PlaytimeRecommendation])
    case setFriendRecommendations(
        recommendations: [SteamFriendRecommendation],
        source: LibraryFriendRecommendationSource,
        emptyState: LibraryFriendRecommendationsEmptyState?
    )
    case setSteamOwnedSyncErrorCode(String?)
    case setAddingToPlaying(LibraryGameIdentifier, isUpdating: Bool)
    case clearAddingToPlaying
    case setSyncingOwnedSteamLibrary(Bool)
    case setUnlinkingSteamAccount(Bool)
    case setSections([LibrarySectionViewState])
    case setError(String)
    case setSuccessMessage(String)
    case setSteamConnectionOnboarding(LibraryOnboardingViewState)
    case clearSuccessMessage
    case clearSteamConnectionOnboarding
    case clearError
    case consumeInitialFocus
}

extension LibraryMutation {
    var logName: String {
        switch self {
        case .setLoading:
            return "setLoading"
        case .setRefreshing:
            return "setRefreshing"
        case .setSummaryLoading:
            return "setSummaryLoading"
        case .setSelectedTab:
            return "setSelectedTab"
        case .setSelectedHighlightChip:
            return "setSelectedHighlightChip"
        case .setSort:
            return "setSort"
        case .setSummaryByTab:
            return "setSummaryByTab"
        case .setServerSummaryByTab:
            return "setServerSummaryByTab"
        case .setPreviewGeneratedAt:
            return "setPreviewGeneratedAt"
        case .setFullGeneratedAt:
            return "setFullGeneratedAt"
        case .setMergedRecentlyPlayedState:
            return "setMergedRecentlyPlayedState"
        case .setSteamState:
            return "setSteamState"
        case .setLibraryItems:
            return "setLibraryItems"
        case .setPlaytimeRecommendations:
            return "setPlaytimeRecommendations"
        case .setFriendRecommendations:
            return "setFriendRecommendations"
        case .setSteamOwnedSyncErrorCode:
            return "setSteamOwnedSyncErrorCode"
        case .setAddingToPlaying:
            return "setAddingToPlaying"
        case .clearAddingToPlaying:
            return "clearAddingToPlaying"
        case .setSyncingOwnedSteamLibrary:
            return "setSyncingOwnedSteamLibrary"
        case .setUnlinkingSteamAccount:
            return "setUnlinkingSteamAccount"
        case .setSections:
            return "setSections"
        case .setError:
            return "setError"
        case .setSuccessMessage:
            return "setSuccessMessage"
        case .setSteamConnectionOnboarding:
            return "setSteamConnectionOnboarding"
        case .clearSuccessMessage:
            return "clearSuccessMessage"
        case .clearSteamConnectionOnboarding:
            return "clearSteamConnectionOnboarding"
        case .clearError:
            return "clearError"
        case .consumeInitialFocus:
            return "consumeInitialFocus"
        }
    }
}
