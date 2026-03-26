import Foundation

// MARK: - HomeMutation

enum HomeMutation {
    case setLoading(Bool)
    case setHomeFeed(HomeFeed)
    case setWishlistedGameIDs(Set<Int>)
    case setError(String)
    case clearError
    case setTranslatedTitles([Int: String])
}
