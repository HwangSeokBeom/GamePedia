import Foundation

// MARK: - UserProfileMapper

enum UserProfileMapper {

    static func toEntity(_ dto: UserProfileDTO) -> UserProfile {
        UserProfile(
            id: dto.id,
            name: dto.name,
            handle: dto.handle,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) },
            badgeTitle: dto.badgeTitle,
            translatedBadgeTitle: dto.translatedBadgeTitle,
            playedGameCount: dto.playedGameCount,
            writtenReviewCount: dto.writtenReviewCount,
            wishlistCount: dto.wishlistCount
        )
    }

    static func toRecentGameEntity(_ dto: RecentGameDTO) -> RecentGame {
        RecentGame(
            gameId: dto.gameId,
            title: dto.title,
            translatedTitle: dto.translatedTitle ?? dto.titleKo,
            coverImageURL: URL(string: dto.coverImageUrl),
            userRating: dto.userRating,
            formattedRating: dto.userRating.map { String(format: "%.1f", $0) },
            formattedLastPlayed: dto.lastPlayedAt.toRelativeDateString()
        )
    }
}
