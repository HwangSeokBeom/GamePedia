import Foundation

extension Int {
    /// Converts large numbers to abbreviated form: 12800 → "12.8K", 1000 → "1.0K"
    var abbreviated: String {
        switch self {
        case 0..<1_000:
            return LocalizedNumberFormatter.integer(self)
        case 1_000..<10_000:
            return "\(LocalizedNumberFormatter.oneFraction(Double(self) / 1_000))K"
        default:
            return "\(LocalizedNumberFormatter.integer(Int((Double(self) / 1_000).rounded())))K"
        }
    }
}
