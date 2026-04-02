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

extension ProfileMutation {
    var logName: String {
        switch self {
        case .setLoading:
            return "setLoading"
        case .setLoggingOut:
            return "setLoggingOut"
        case .setDeletingAccount:
            return "setDeletingAccount"
        case .setLoadingSteamLinkStatus:
            return "setLoadingSteamLinkStatus"
        case .setUnlinkingSteamAccount:
            return "setUnlinkingSteamAccount"
        case .setAuthenticatedUser:
            return "setAuthenticatedUser"
        case .setProfileSummary:
            return "setProfileSummary"
        case .setRecentlyPlayedGames:
            return "setRecentlyPlayedGames"
        case .setRecentPlayLoadState:
            return "setRecentPlayLoadState"
        case .setWrittenReviewCount:
            return "setWrittenReviewCount"
        case .setFriendCount:
            return "setFriendCount"
        case .setFriendActivityCount:
            return "setFriendActivityCount"
        case .setWishlistCount:
            return "setWishlistCount"
        case .setHasMoreRecentPlayed:
            return "setHasMoreRecentPlayed"
        case .setSelectedTitles:
            return "setSelectedTitles"
        case .setSelectedTitleSelection:
            return "setSelectedTitleSelection"
        case .setSelectedBadgeTitles:
            return "setSelectedBadgeTitles"
        case .setSteamLinkStatus:
            return "setSteamLinkStatus"
        case .setError:
            return "setError"
        case .setSuccessMessage:
            return "setSuccessMessage"
        case .clearError:
            return "clearError"
        case .clearSuccessMessage:
            return "clearSuccessMessage"
        case .setTranslatedRecentGameTitles:
            return "setTranslatedRecentGameTitles"
        }
    }
}
