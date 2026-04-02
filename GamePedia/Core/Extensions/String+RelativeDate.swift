import Foundation

extension String {
    /// Converts ISO8601 string to relative Korean date string: "3일 전"
    func toRelativeDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: self) else {
            // Try without fractional seconds
            formatter.formatOptions = .withInternetDateTime
            guard let date2 = formatter.date(from: self) else {
                return ""
            }
            return date2.relativeKorean
        }
        return date.relativeKorean
    }
}

private extension Date {
    var relativeKorean: String {
        let seconds = Int(Date().timeIntervalSince(self))
        switch seconds {
        case ..<60:
            return "방금 전"
        case 60..<3_600:
            return "\(seconds / 60)분 전"
        case 3_600..<86_400:
            return "\(seconds / 3_600)시간 전"
        case 86_400..<2_592_000:
            return "\(seconds / 86_400)일 전"
        case 2_592_000..<31_536_000:
            return "\(seconds / 2_592_000)달 전"
        default:
            return "\(seconds / 31_536_000)년 전"
        }
    }
}
