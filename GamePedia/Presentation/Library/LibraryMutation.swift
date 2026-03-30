import Foundation

enum LibraryMutation {
    case setLoading(Bool)
    case setRefreshing(Bool)
    case setSort(LibrarySortOption)
    case setSteamState(isConnected: Bool, isSyncAvailable: Bool, errorCode: String?)
    case setLibraryItems(
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        likedGames: [Game],
        reviews: [ReviewedGame]
    )
    case setAddingToPlaying(LibraryGameIdentifier, isUpdating: Bool)
    case clearAddingToPlaying
    case setSections([LibrarySectionViewState])
    case setError(String)
    case clearError
    case consumeInitialFocus
}
