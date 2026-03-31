import Foundation

enum SteamPlaytimeFormatter {
    static func compactPlaytimeText(minutes: Int?) -> String? {
        guard let normalizedMinutes = normalizedMinutes(from: minutes) else { return nil }

        if normalizedMinutes < 60 {
            return "플레이 \(normalizedMinutes)분"
        }

        return "플레이 \(normalizedMinutes / 60)시간"
    }

    static func expandedPlaytimeValue(minutes: Int?) -> String? {
        guard let normalizedMinutes = normalizedMinutes(from: minutes) else { return nil }

        if normalizedMinutes < 60 {
            return "\(normalizedMinutes)분"
        }

        let hours = normalizedMinutes / 60
        let remainingMinutes = normalizedMinutes % 60
        if remainingMinutes == 0 {
            return "\(hours)시간"
        }

        return "\(hours)시간 \(remainingMinutes)분"
    }

    static func recentPlaytimeText(
        recentPlaytimeMinutes: Int?,
        fallbackPlaytimeMinutes: Int?
    ) -> String? {
        if let recentPlaytimeMinutes = normalizedMinutes(from: recentPlaytimeMinutes) {
            if recentPlaytimeMinutes < 60 {
                return "최근 2주 \(recentPlaytimeMinutes)분"
            }

            return "최근 2주 \(recentPlaytimeMinutes / 60)시간"
        }

        return compactPlaytimeText(minutes: fallbackPlaytimeMinutes)
    }

    private static func normalizedMinutes(from minutes: Int?) -> Int? {
        guard let minutes, minutes > 0 else { return nil }
        return minutes
    }
}
