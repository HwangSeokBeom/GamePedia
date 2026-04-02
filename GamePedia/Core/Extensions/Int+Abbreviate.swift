import Foundation

extension Int {
    /// Converts large numbers to abbreviated form: 12800 → "12.8K", 1000 → "1.0K"
    var abbreviated: String {
        switch self {
        case 0..<1_000:
            return "\(self)"
        case 1_000..<10_000:
            return String(format: "%.1fK", Double(self) / 1_000)
        default:
            return String(format: "%.0fK", Double(self) / 1_000)
        }
    }
}
