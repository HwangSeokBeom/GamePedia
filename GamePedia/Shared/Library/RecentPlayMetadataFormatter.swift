import Foundation

struct RecentPlayDisplayParts: Equatable {
    let relativeTimeText: String?
    let durationText: String?
    let finalText: String
}

enum RecentPlayMetadataFormatter {
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

        let durationText = normalizedRecentPlaytimeMinutes.map { "최근 플레이 \(expandedMinutesText($0))" }

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
            return "최근 플레이 기록"
        default:
            return "최근 플레이 기록"
        }
    }

    private static func normalizeMinutes(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0 else { return nil }
        return minutes
    }

    private static func expandedMinutesText(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)분"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)시간"
        }
        return "\(hours)시간 \(remainingMinutes)분"
    }

    private static func makeRelativeText(from date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))

        switch seconds {
        case ..<60:
            return "방금 전"
        case 60..<3_600:
            return "\(seconds / 60)분 전"
        case 3_600..<86_400:
            return "\(seconds / 3_600)시간 전"
        case 86_400..<604_800:
            return "\(seconds / 86_400)일 전"
        case 604_800..<2_592_000:
            return "\(seconds / 604_800)주 전"
        case 2_592_000..<31_536_000:
            return "\(seconds / 2_592_000)달 전"
        default:
            return "\(seconds / 31_536_000)년 전"
        }
    }
}
