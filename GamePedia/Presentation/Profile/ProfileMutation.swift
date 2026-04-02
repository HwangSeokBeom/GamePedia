import Foundation

// MARK: - ProfileMutation

enum ProfileMutation {
    case setLoading(Bool)
    case setLoggingOut(Bool)
    case setDeletingAccount(Bool)
    case setAuthenticatedUser(AuthUser)
    case setRecentGames([RecentGame])
    case setWrittenReviewCount(Int)
    case setWishlistCount(Int)
    case setError(String)
    case clearError
    case setTranslatedRecentGameTitles([Int: String])
}
