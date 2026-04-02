import Foundation

enum LibraryMutation {
    case setLoading(Bool)
    case setRefreshing(Bool)
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
