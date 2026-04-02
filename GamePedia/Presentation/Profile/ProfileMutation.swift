import Foundation

// MARK: - ProfileMutation

enum ProfileMutation {
    case setLoading(Bool)
    case setLoggingOut(Bool)
    case setDeletingAccount(Bool)
    case setLoadingSteamLinkStatus(Bool)
    case setUnlinkingSteamAccount(Bool)
    case setAuthenticatedUser(AuthUser)
    case setProfileSummary(UserProfile)
    case setRecentlyPlayedGames([RecentGame])
    case setRecentPlayLoadState(ProfileRecentPlayLoadState)
    case setWrittenReviewCount(Int)
    case setFriendCount(Int)
    case setFriendActivityCount(Int)
    case setWishlistCount(Int)
    case setHasMoreRecentPlayed(Bool)
    case setSelectedTitles([String])
    case setSelectedTitleSelection(title: String?, key: String?)
    case setSelectedBadgeTitles([String])
    case setSteamLinkStatus(SteamLinkStatus)
    case setError(String)
    case setSuccessMessage(String)
    case clearError
    case clearSuccessMessage
    case setTranslatedRecentGameTitles([Int: String])
}
