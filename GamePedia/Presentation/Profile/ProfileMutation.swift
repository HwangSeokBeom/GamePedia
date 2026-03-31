import Foundation

// MARK: - ProfileMutation

enum ProfileMutation {
    case setLoading(Bool)
    case setLoggingOut(Bool)
    case setDeletingAccount(Bool)
    case setLoadingSteamLinkStatus(Bool)
    case setUnlinkingSteamAccount(Bool)
    case setAuthenticatedUser(AuthUser)
    case setRecentGames([RecentGame])
    case setWrittenReviewCount(Int)
    case setWishlistCount(Int)
    case setSteamLinkStatus(SteamLinkStatus)
    case setError(String)
    case setSuccessMessage(String)
    case clearError
    case clearSuccessMessage
    case setTranslatedRecentGameTitles([Int: String])
}
