import Foundation

enum LibraryMutation {
    case setLoading(Bool)
    case setRefreshing(Bool)
    case setSort(LibrarySortOption)
    case setSteamState(isConnected: Bool, isSyncAvailable: Bool, errorCode: String?)
    case setLibraryItems(
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        ownedGames: [LibraryGameSummary],
        backlogGames: [LibraryGameSummary],
        likedGames: [Game],
        reviews: [ReviewedGame]
    )
    case setAddingToPlaying(LibraryGameIdentifier, isUpdating: Bool)
    case clearAddingToPlaying
    case setSyncingOwnedSteamLibrary(Bool)
    case setSections([LibrarySectionViewState])
    case setError(String)
    case setSuccessMessage(String)
    case clearSuccessMessage
    case clearError
    case consumeInitialFocus
}
