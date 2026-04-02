import Foundation

// MARK: - UserProfile

struct UserProfile {
    let id: Int
    let email: String?
    let name: String
    let handle: String
    let avatarURL: URL?
    let badgeTitle: String?
    let translatedBadgeTitle: String?
    let selectedTitle: String?
    let selectedTitles: [String]
    let explicitSelected: Bool?
    let availableTitles: [String]
    let profileTags: [String]
    let friendCount: Int
    let likeCount: Int
    let playedGameCount: Int
    let writtenReviewCount: Int
    let wishlistCount: Int
    let recentPlayedPreview: [RecentGame]
    let hasMoreRecentPlayed: Bool
    let recentPlayedCount: Int
    let recentPlayedSource: String?

    var resolvedBadgeTitle: String? {
        Self.resolvedText(selectedTitle, fallback: Self.resolvedText(translatedBadgeTitle, fallback: badgeTitle))
    }

    var resolvedBadgeTitles: [String] {
        guard explicitSelected != false else { return [] }
        let normalizedSelectedTitles = selectedTitles.compactMap { Self.resolvedText($0, fallback: nil) }
        if normalizedSelectedTitles.isEmpty == false {
            return Array(normalizedSelectedTitles.prefix(1))
        }
        if let resolvedBadgeTitle {
            return [resolvedBadgeTitle]
        }
        return []
    }

    func replacingTranslated(translatedBadgeTitle: String?) -> UserProfile {
        UserProfile(
            id: id,
            email: email,
            name: name,
            handle: handle,
            avatarURL: avatarURL,
            badgeTitle: badgeTitle,
            translatedBadgeTitle: translatedBadgeTitle ?? self.translatedBadgeTitle,
            selectedTitle: selectedTitle,
            selectedTitles: selectedTitles,
            explicitSelected: explicitSelected,
            availableTitles: availableTitles,
            profileTags: profileTags,
            friendCount: friendCount,
            likeCount: likeCount,
            playedGameCount: playedGameCount,
            writtenReviewCount: writtenReviewCount,
            wishlistCount: wishlistCount,
            recentPlayedPreview: recentPlayedPreview,
            hasMoreRecentPlayed: hasMoreRecentPlayed,
            recentPlayedCount: recentPlayedCount,
            recentPlayedSource: recentPlayedSource
        )
    }
}

// MARK: - RecentGame

struct RecentGame {
    let gameId: Int
    let igdbGameId: Int?
    let externalGameId: String?
    let detailAvailable: Bool
    let title: String
    let translatedTitle: String?
    let coverImageURL: URL?
    let userRating: Double?
    let formattedRating: String?    // "5.0" or nil if no rating
    let formattedLastPlayed: String
    let lastPlayedAt: Date?
    let lastPlayedAtSource: String?
    let hasReliableLastPlayedAt: Bool
    let recentPlaytimeMinutes: Int?
    let fallbackReason: String?

    var displayTitle: String { resolvedTitle }

    var resolvedTitle: String {
        title
    }

    var resolvedDetailGameId: Int? {
        if let igdbGameId, igdbGameId > 0 {
            return igdbGameId
        }
        return gameId > 0 ? gameId : nil
    }

    func replacingTranslated(translatedTitle: String?) -> RecentGame {
        RecentGame(
            gameId: gameId,
            igdbGameId: igdbGameId,
            externalGameId: externalGameId,
            detailAvailable: detailAvailable,
            title: title,
            translatedTitle: translatedTitle ?? self.translatedTitle,
            coverImageURL: coverImageURL,
            userRating: userRating,
            formattedRating: formattedRating,
            formattedLastPlayed: formattedLastPlayed,
            lastPlayedAt: lastPlayedAt,
            lastPlayedAtSource: lastPlayedAtSource,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            fallbackReason: fallbackReason
        )
    }

    func replacingRecentPlayMetadata(
        formattedLastPlayed: String,
        lastPlayedAt: Date?,
        lastPlayedAtSource: String?,
        hasReliableLastPlayedAt: Bool,
        recentPlaytimeMinutes: Int?,
        fallbackReason: String?
    ) -> RecentGame {
        RecentGame(
            gameId: gameId,
            igdbGameId: igdbGameId,
            externalGameId: externalGameId,
            detailAvailable: detailAvailable,
            title: title,
            translatedTitle: translatedTitle,
            coverImageURL: coverImageURL,
            userRating: userRating,
            formattedRating: formattedRating,
            formattedLastPlayed: formattedLastPlayed,
            lastPlayedAt: lastPlayedAt,
            lastPlayedAtSource: lastPlayedAtSource,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            fallbackReason: fallbackReason
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
