import Foundation

extension String {
    func toAbsoluteDateString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let resolvedDate: Date?
        if let date = formatter.date(from: self) {
            resolvedDate = date
        } else {
            formatter.formatOptions = .withInternetDateTime
            resolvedDate = formatter.date(from: self)
        }

        guard let resolvedDate else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = .autoupdatingCurrent
        dateFormatter.dateFormat = "yyyy.MM.dd"
        return dateFormatter.string(from: resolvedDate)
    }
}
