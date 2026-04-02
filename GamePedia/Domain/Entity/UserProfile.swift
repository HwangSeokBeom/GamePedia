import Foundation

// MARK: - UserProfile

struct UserProfile {
    let id: Int
    let name: String
    let handle: String
    let avatarURL: URL?
    let badgeTitle: String?
    let translatedBadgeTitle: String?
    let playedGameCount: Int
    let writtenReviewCount: Int
    let wishlistCount: Int

    var resolvedBadgeTitle: String? {
        Self.resolvedText(translatedBadgeTitle, fallback: badgeTitle)
    }

    func replacingTranslated(translatedBadgeTitle: String?) -> UserProfile {
        UserProfile(
            id: id,
            name: name,
            handle: handle,
            avatarURL: avatarURL,
            badgeTitle: badgeTitle,
            translatedBadgeTitle: translatedBadgeTitle ?? self.translatedBadgeTitle,
            playedGameCount: playedGameCount,
            writtenReviewCount: writtenReviewCount,
            wishlistCount: wishlistCount
        )
    }
}

// MARK: - RecentGame

struct RecentGame {
    let gameId: Int
    let title: String
    let translatedTitle: String?
    let coverImageURL: URL?
    let userRating: Double?
    let formattedRating: String?    // "5.0" or nil if no rating
    let formattedLastPlayed: String // "10시간 전 플레이 · 2분 전"

    var displayTitle: String { resolvedTitle }

    var resolvedTitle: String {
        Self.resolvedText(translatedTitle, fallback: title) ?? title
    }

    func replacingTranslated(translatedTitle: String?) -> RecentGame {
        RecentGame(
            gameId: gameId,
            title: title,
            translatedTitle: translatedTitle ?? self.translatedTitle,
            coverImageURL: coverImageURL,
            userRating: userRating,
            formattedRating: formattedRating,
            formattedLastPlayed: formattedLastPlayed
        )
    }
}

private extension UserProfile {
    static func resolvedText(_ translated: String?, fallback: String?) -> String? {
        let normalizedTranslated = translated?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedTranslated, !normalizedTranslated.isEmpty {
            return normalizedTranslated
        }

        let normalizedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedFallback, !normalizedFallback.isEmpty {
            return normalizedFallback
        }

        return fallback
    }
}

private extension RecentGame {
    static func resolvedText(_ translated: String?, fallback: String?) -> String? {
        let normalizedTranslated = translated?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedTranslated, !normalizedTranslated.isEmpty {
            return normalizedTranslated
        }

        let normalizedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedFallback, !normalizedFallback.isEmpty {
            return normalizedFallback
        }

        return fallback
    }
}
