import UIKit

// MARK: - App Color Palette

extension UIColor {

    // MARK: Backgrounds
    static let gpBackground = dynamic(light: "#F3F5F9", dark: "#0B0B0E")
    static let gpSecondaryBackground = dynamic(light: "#FBFCFE", dark: "#14161B")
    static let gpSurface = dynamic(light: "#FBFCFE", dark: "#14161B")
    static let gpSurfaceElevated = dynamic(light: "#F8FAFD", dark: "#1B1E26")
    static let gpCardBackground = gpSurfaceElevated
    static let gpInputBackground = dynamic(light: "#FFFFFF", dark: "#171922")
    static let gpNavigationBarBackground = gpBackground
    static let gpTabBarBackground = dynamic(light: "#FDFEFF", dark: "#12141B")

    // MARK: Primary
    static let gpPrimary = UIColor(hex: "#6C63FF")
    static let gpPrimaryLight = dynamic(light: "#5E56EB", dark: "#8B85FF")
    static let gpAccent = gpPrimary
    static let gpOnPrimary = UIColor.white

    // MARK: Text
    static let gpTextPrimary = dynamic(light: "#11131A", dark: "#F7F8FB")
    static let gpTextSecondary = dynamic(light: "#5D6472", dark: "#A0A7B5")
    static let gpTextTertiary = dynamic(light: "#8A92A2", dark: "#6B7280")
    static let gpTextInverse = dynamic(light: "#FFFFFF", dark: "#0B0B0E")

    // MARK: Accent
    static let gpStar = dynamic(light: "#F4B400", dark: "#FFD35A")
    static let gpBadge = dynamic(light: "#3D82D9", dark: "#62A8FF")
    static let gpRed = dynamic(light: "#E34D4D", dark: "#FF6B6B")
    static let gpOrange = dynamic(light: "#E58B2B", dark: "#FFB14A")
    static let gpTeal = dynamic(light: "#2FA59B", dark: "#4ECDC4")

    // MARK: Separators / Utility
    static let gpSeparator = dynamic(light: "#D9DFEA", dark: "#2A2F3C")
    static let gpBorder = gpSeparator
    static let gpShadow = UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor.black.withAlphaComponent(0.34)
        default:
            return UIColor.black.withAlphaComponent(0.12)
        }
    }
    static let gpHeroGradientEnd = dynamic(light: "#F3F5F9", dark: "#0B0B0E")
    static let gpSocialButtonBackground = dynamic(light: "#FFFFFF", dark: "#11141C")
    static let gpSocialButtonForeground = dynamic(light: "#111216", dark: "#F7F8FB")
    static let gpSocialButtonBorder = dynamic(light: "#D8DDE8", dark: "#2A2F3C")
    static let gpAvatarInitialText = UIColor.white

    static func dynamic(light: String, dark: String) -> UIColor {
        UIColor { trait in
            switch trait.userInterfaceStyle {
            case .dark:
                return UIColor(hex: dark)
            default:
                return UIColor(hex: light)
            }
        }
    }

    func resolvedCGColor(with traitCollection: UITraitCollection) -> CGColor {
        resolvedColor(with: traitCollection).cgColor
    }
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
