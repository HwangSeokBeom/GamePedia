import Foundation

enum LibraryIntent {
    case viewDidLoad
    case pullToRefresh
    case didSelectSort(Int)
    case connectSteamButtonTapped
    case retrySteamSyncTapped
    case didTapSteamLink
    case didTapRecentlyPlayedGame(LibraryGameIdentifier)
    case didTapAddToPlaying(gameID: LibraryGameIdentifier, source: GameSource)
    case didTapWishlistGame(LibraryGameIdentifier)
    case didTapPlayingGame(LibraryGameIdentifier)
    case didTapReviewedGame(LibraryGameIdentifier)
    case didTapSeeAllRecentlyPlayed
    case didTapSeeAllReviewed
    case didConfirmRemoveFavorite(LibraryGameIdentifier)
    case didConsumeInitialFocus
}
