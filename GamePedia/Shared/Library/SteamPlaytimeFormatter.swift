import Foundation

enum SteamPlaytimeFormatter {
    static func compactPlaytimeText(minutes: Int?) -> String? {
        guard let normalizedMinutes = normalizedMinutes(from: minutes) else { return nil }
        return L10n.tr("Localizable", "steam.playtime.compact", durationText(minutes: normalizedMinutes))
    }

    static func expandedPlaytimeValue(minutes: Int?) -> String? {
        guard let normalizedMinutes = normalizedMinutes(from: minutes) else { return nil }
        return durationText(minutes: normalizedMinutes)
    }

    static func recentPlaytimeText(
        recentPlaytimeMinutes: Int?,
        fallbackPlaytimeMinutes: Int?
    ) -> String? {
        if let recentPlaytimeMinutes = normalizedMinutes(from: recentPlaytimeMinutes) {
            return L10n.tr("Localizable", "steam.playtime.recent", durationText(minutes: recentPlaytimeMinutes))
        }

        return compactPlaytimeText(minutes: fallbackPlaytimeMinutes)
    }

    private static func normalizedMinutes(from minutes: Int?) -> Int? {
        guard let minutes, minutes > 0 else { return nil }
        return minutes
    }

    private static func durationText(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = minutes < 60 ? [.minute] : [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.maximumUnitCount = minutes % 60 == 0 ? 1 : 2
        var calendar = Calendar.current
        calendar.locale = Locale.current
        formatter.calendar = calendar
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)"
    }
}
