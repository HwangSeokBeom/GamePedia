import Foundation

// MARK: - UserProfileDTO

struct UserProfileDTO: Decodable {
    let id: Int
    let name: String
    let handle: String              // e.g. "@ijunhyik_gamer"
    let avatarUrl: String?
    let badgeTitle: String?         // e.g. "Pro Reviewer"
    let translatedBadgeTitle: String?
    let playedGameCount: Int
    let writtenReviewCount: Int
    let wishlistCount: Int
}

// MARK: - RecentGameListResponseDTO

struct RecentGameListResponseDTO: Decodable {
    let recentGames: [RecentGameDTO]
}

// MARK: - RecentGameDTO

struct RecentGameDTO: Decodable {
    let gameId: Int
    let title: String
    let titleKo: String?
    let translatedTitle: String?
    let coverImageUrl: String
    let userRating: Double?
    let lastPlayedAt: String        // ISO8601 string
}
