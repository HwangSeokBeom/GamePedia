import Foundation

// MARK: - UserProfileMapper

enum UserProfileMapper {

    static func toEntity(_ dto: UserProfileDTO) -> UserProfile {
        UserProfile(
            id: dto.id,
            email: dto.email,
            name: dto.name,
            handle: dto.handle,
            avatarURL: dto.avatarUrl.flatMap { URL(string: $0) },
            badgeTitle: dto.badgeTitle,
            translatedBadgeTitle: dto.translatedBadgeTitle,
            selectedTitle: dto.selectedTitle,
            selectedTitles: uniqueStrings(dto.selectedTitles),
            explicitSelected: dto.explicitSelected,
            availableTitles: uniqueStrings(dto.availableTitles),
            profileTags: uniqueStrings(dto.profileTags),
            friendCount: max(dto.friendCount, 0),
            likeCount: max(dto.likeCount, 0),
            playedGameCount: dto.playedGameCount,
            writtenReviewCount: dto.writtenReviewCount,
            wishlistCount: dto.wishlistCount,
            recentPlayedPreview: dto.recentPlayedPreview.map(toRecentGameEntity),
            hasMoreRecentPlayed: dto.hasMoreRecentPlayed,
            recentPlayedCount: dto.recentPlayedCount,
            recentPlayedSource: dto.recentPlayedSource
        )
    }

    static func toRecentGameEntity(_ dto: RecentGameDTO) -> RecentGame {
        let lastPlayedAt = parseLastPlayedDate(dto.lastPlayedAt)
        let hasReliableLastPlayedAt = resolveReliableLastPlayedAt(
            explicitReliability: dto.hasReliableLastPlayedAt,
            lastPlayedAtSource: dto.lastPlayedAtSource
        )
        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: dto.userRating,
            aggregatedRating: dto.aggregatedRating,
            totalRating: dto.totalRating
        )
        let display = RecentPlayMetadataFormatter.makeDisplay(
            lastPlayedAt: lastPlayedAt,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlaytimeMinutes: dto.recentPlaytimeMinutes,
            fallbackReason: dto.fallbackReason
        )
        let formattedLastPlayed = display.finalText
        let resolvedDetailGameId = dto.igdbGameId ?? (dto.gameId > 0 ? dto.gameId : nil)
        let detailAvailable = dto.detailAvailable ?? (resolvedDetailGameId != nil)
        let chosenTimeSource: String
        if hasReliableLastPlayedAt, lastPlayedAt != nil {
            chosenTimeSource = "item.lastPlayedAt"
        } else if dto.recentPlaytimeMinutes ?? 0 > 0 {
            chosenTimeSource = "item.recentPlaytimeMinutes"
        } else if let lastPlayedAtSource = dto.lastPlayedAtSource, lastPlayedAtSource.isEmpty == false {
            chosenTimeSource = "fallback.\(lastPlayedAtSource)"
        } else {
            chosenTimeSource = "fallback.\(dto.fallbackReason ?? "untrusted")"
        }
        let timestampUsedForRelativeText = display.relativeTimeText == nil
            ? "nil"
            : (lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil")
        print(
            "[RecentPlayDisplay] " +
            "screen=Profile.mapper " +
            "title=\(dto.title) " +
            "rawLastPlayedAt=\(dto.lastPlayedAt) " +
            "lastPlayedAt=\(lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil") " +
            "hasReliableLastPlayedAt=\(hasReliableLastPlayedAt) " +
            "recentPlaytimeMinutes=\(dto.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
            "timestampUsedForRelativeText=\(timestampUsedForRelativeText) " +
            "relativeTime=\(display.relativeTimeText ?? "nil") " +
            "fallbackReason=\(dto.fallbackReason ?? "nil") " +
            "chosenSource=\(chosenTimeSource) " +
            "finalText=\(formattedLastPlayed)"
        )
        let recentGame = RecentGame(
            gameId: dto.gameId,
            igdbGameId: resolvedDetailGameId,
            externalGameId: dto.externalGameId,
            detailAvailable: detailAvailable,
            title: dto.title,
            translatedTitle: dto.translatedTitle ?? dto.titleKo,
            coverImageURL: URL(string: dto.coverImageUrl),
            userRating: ratingDisplay.normalizedRating,
            formattedRating: ratingDisplay.displayText,
            formattedLastPlayed: formattedLastPlayed,
            lastPlayedAt: hasReliableLastPlayedAt ? lastPlayedAt : nil,
            lastPlayedAtSource: dto.lastPlayedAtSource,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlaytimeMinutes: dto.recentPlaytimeMinutes,
            fallbackReason: dto.fallbackReason
        )
        let userRatingLogValue = dto.userRating.map { String($0) } ?? "nil"
        let aggregatedRatingLogValue = dto.aggregatedRating.map { String($0) } ?? "nil"
        let totalRatingLogValue = dto.totalRating.map { String($0) } ?? "nil"
        print(
            "[RatingMapping] " +
            "screen=Profile.mapper " +
            "title=\(recentGame.resolvedTitle) " +
            "userRating=\(userRatingLogValue) " +
            "aggregatedRating=\(aggregatedRatingLogValue) " +
            "totalRating=\(totalRatingLogValue) " +
            "selectedDisplaySource=\(ratingDisplay.selectedDisplaySource) " +
            "finalDisplayText=\(ratingDisplay.displayText ?? "nil")"
        )
        print(
            "[RecentPlayMapping] " +
            "screen=Profile.mapper " +
            "title=\(recentGame.resolvedTitle) " +
            "viewState.lastPlayedAt=\(recentGame.lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil") " +
            "viewState.recentPlaytimeMinutes=\(recentGame.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
            "viewState.hasReliableLastPlayedAt=\(recentGame.hasReliableLastPlayedAt)"
        )
        return recentGame
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            guard seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private static func parseLastPlayedDate(_ rawValue: String) -> Date? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmedValue) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: trimmedValue) {
            return date
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss"
        ]

        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: trimmedValue) {
                return date
            }
        }

        if let timeInterval = Double(trimmedValue) {
            let normalizedTimeInterval = timeInterval > 10_000_000_000 ? (timeInterval / 1000.0) : timeInterval
            return Date(timeIntervalSince1970: normalizedTimeInterval)
        }

        return nil
    }
    private static func resolveReliableLastPlayedAt(
        explicitReliability: Bool?,
        lastPlayedAtSource: String?
    ) -> Bool {
        if let explicitReliability {
            return explicitReliability
        }

        guard let normalizedSource = lastPlayedAtSource?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            normalizedSource.isEmpty == false else {
            return false
        }

        let trustedSources: Set<String> = [
            "reliable",
            "trusted",
            "play_history",
            "recent_play_history",
            "session_history",
            "activity_event"
        ]
        return trustedSources.contains(normalizedSource)
    }
}
