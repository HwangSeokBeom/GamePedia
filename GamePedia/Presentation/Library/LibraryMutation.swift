import Foundation

enum LibraryMutation {
    case setLoading(Bool)
    case setRefreshing(Bool)
    case setSort(LibrarySortOption)
    case setSteamState(isConnected: Bool, syncStatus: SteamSyncStatus, isSyncAvailable: Bool, errorCode: String?)
    case setLibraryItems(
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        ownedGames: [LibraryGameSummary],
        backlogGames: [LibraryGameSummary],
        likedGames: [Game],
        reviews: [ReviewedGame]
    )
    case setPlaytimeRecommendations([PlaytimeRecommendation])
    case setFriendRecommendations([SteamFriendRecommendation])
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
