import Foundation

struct RecentPlayDisplayParts: Equatable {
    let relativeTimeText: String?
    let durationText: String?
    let finalText: String
}

enum RecentPlayMetadataFormatter {
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .current
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = [.dropAll]
        formatter.maximumUnitCount = 2
        return formatter
    }()

    static func format(
        now: Date = Date(),
        lastPlayedAt: Date?,
        hasReliableLastPlayedAt: Bool,
        recentPlaytimeMinutes: Int?,
        fallbackReason: String?
    ) -> String {
        makeDisplay(
            now: now,
            lastPlayedAt: lastPlayedAt,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            fallbackReason: fallbackReason
        ).finalText
    }

    static func makeDisplay(
        now: Date = Date(),
        lastPlayedAt: Date?,
        hasReliableLastPlayedAt: Bool,
        recentPlaytimeMinutes: Int?,
        fallbackReason: String?
    ) -> RecentPlayDisplayParts {
        let normalizedRecentPlaytimeMinutes = normalizeMinutes(recentPlaytimeMinutes)
        let relativeTimeText: String? = {
            guard hasReliableLastPlayedAt, let lastPlayedAt else { return nil }
            return makeRelativeText(from: lastPlayedAt, now: now)
        }()

        let durationText = normalizedRecentPlaytimeMinutes.map { recentPlayDurationText($0) }

        let finalText: String
        if let relativeTimeText, let durationText {
            finalText = "\(relativeTimeText) · \(durationText)"
        } else if let relativeTimeText {
            finalText = relativeTimeText
        } else if let durationText {
            finalText = durationText
        } else {
            finalText = fallbackText(for: fallbackReason)
        }

        return RecentPlayDisplayParts(
            relativeTimeText: relativeTimeText,
            durationText: durationText,
            finalText: finalText
        )
    }

    static func fallbackText(for fallbackReason: String?) -> String {
        let normalizedReason = fallbackReason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalizedReason {
        case "timestamp_unavailable":
            return L10n.Empty.noRecentPlay
        default:
            return L10n.Empty.noRecentPlay
        }
    }

    private static func normalizeMinutes(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0 else { return nil }
        return minutes
    }

    private static func recentPlayDurationText(_ minutes: Int) -> String {
        guard let localizedDuration = durationFormatter.string(from: TimeInterval(minutes * 60)) else {
            return L10n.Profile.Section.recentPlay
        }
        return L10n.Profile.RecentPlay.durationFormat(localizedDuration)
    }

    private static func makeRelativeText(from date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 {
            return L10n.Common.Time.justNow
        }
        return relativeDateFormatter.localizedString(for: date, relativeTo: now)
    }
}
