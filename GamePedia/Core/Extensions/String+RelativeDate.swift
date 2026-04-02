import Foundation

extension String {
    /// Converts ISO8601 string to a locale-aware relative date string.
    func toRelativeDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: self) else {
            // Try without fractional seconds
            formatter.formatOptions = .withInternetDateTime
            guard let date2 = formatter.date(from: self) else {
                return ""
            }
            return date2.localizedRelativeText
        }
        return date.localizedRelativeText
    }
}

private extension Date {
    var localizedRelativeText: String {
        if abs(timeIntervalSinceNow) < 60 {
            return L10n.tr("Localizable", "date.relative.now")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .autoupdatingCurrent
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
