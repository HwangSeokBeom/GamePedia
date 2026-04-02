import Foundation

enum LibraryIntent {
    case viewDidLoad
    case pullToRefresh
    case didSelectPrimaryTab(Int)
    case didSelectHighlightChip(Int)
    case didSelectSort(Int)
    case syncOwnedSteamLibraryButtonTapped
    case connectSteamButtonTapped
    case steamPrivacyGuideButtonTapped
    case retrySteamPrivacyGuideTapped
    case retrySteamSyncTapped
    case retryFriendRecommendationsTapped
    case retryPlaytimeRecommendationsTapped
    case unlinkSteamConfirmed
    case didTapSteamLink
    case didTapRecentlyPlayedGame(LibraryGameIdentifier)
    case didTapAddToPlaying(gameID: LibraryGameIdentifier, source: GameSource)
    case didTapWishlistGame(LibraryGameIdentifier)
    case didTapPlayingGame(LibraryGameIdentifier)
    case didTapPlaytimeRecommendationGame(LibraryGameIdentifier)
    case didTapFriendRecommendationGame(LibraryGameIdentifier)
    case didTapReviewedGame(LibraryGameIdentifier)
    case didTapSeeAllRecentlyPlayed
    case didTapSeeAllPlaying
    case didTapSeeAllOwned
    case didTapSeeAllWishlist
    case didTapSeeAllReviewed
    case didTapSeeAllFriendRecommendations
    case didTapSeeAllPlaytimeRecommendations
    case didConfirmRemoveFavorite(LibraryGameIdentifier)
    case didConsumeSuccessMessage
    case didConsumeSteamConnectionOnboarding
    case didConsumeInitialFocus
}
