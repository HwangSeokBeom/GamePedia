import UIKit

// MARK: - App Color Palette

extension UIColor {

    // MARK: Backgrounds
    static let gpBackground      = UIColor(hex: "#0D0D0D")
    static let gpSurface         = UIColor(hex: "#1A1A1A")
    static let gpSurfaceElevated = UIColor(hex: "#242424")

    // MARK: Primary
    static let gpPrimary         = UIColor(hex: "#6C63FF")   // purple-ish from wireframe
    static let gpPrimaryLight    = UIColor(hex: "#8B85FF")

    // MARK: Text
    static let gpTextPrimary     = UIColor.white
    static let gpTextSecondary   = UIColor(hex: "#A0A0A0")
    static let gpTextTertiary    = UIColor(hex: "#666666")

    // MARK: Accent
    static let gpStar            = UIColor(hex: "#FFD700")   // gold star
    static let gpBadge           = UIColor(hex: "#4A90D9")   // blue badge
    static let gpRed             = UIColor(hex: "#FF4444")

    // MARK: Separator
    static let gpSeparator       = UIColor(hex: "#2A2A2A")
}

// MARK: - Hex Init

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8)  / 255
        let b = CGFloat(rgb & 0x0000FF)          / 255

        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
