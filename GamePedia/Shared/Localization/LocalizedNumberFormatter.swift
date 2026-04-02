import Foundation

enum LocalizedNumberFormatter {
    private static func makeFormatter(
        minimumFractionDigits: Int,
        maximumFractionDigits: Int
    ) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter
    }

    private static let integerFormatter = makeFormatter(
        minimumFractionDigits: 0,
        maximumFractionDigits: 0
    )

    private static let oneFractionFormatter = makeFormatter(
        minimumFractionDigits: 1,
        maximumFractionDigits: 1
    )

    private static let optionalFractionFormatter = makeFormatter(
        minimumFractionDigits: 0,
        maximumFractionDigits: 1
    )

    static func integer(_ value: Int) -> String {
        integerFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func oneFraction(_ value: Double) -> String {
        oneFractionFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func optionalFraction(_ value: Double) -> String {
        optionalFractionFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
