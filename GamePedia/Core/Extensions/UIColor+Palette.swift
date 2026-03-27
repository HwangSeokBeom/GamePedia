import UIKit

// MARK: - App Color Palette

extension UIColor {

    // MARK: Backgrounds
    static let gpBackground = dynamic(light: "#F8F8FA", dark: "#0B0B0E")
    static let gpSecondaryBackground = dynamic(light: "#F0F0F5", dark: "#1A1A1E")
    static let gpSurface = dynamic(light: "#F0F0F5", dark: "#1A1A1E")
    static let gpSurfaceElevated = dynamic(light: "#F0F0F5", dark: "#1A1A1E")
    static let gpCardBackground = dynamic(light: "#FFFFFF", dark: "#16161A")
    static let gpInputBackground = dynamic(light: "#FFFFFF", dark: "#16161A")
    static let gpNavigationBarBackground = gpBackground
    static let gpTabBarBackground = UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor(hex: "#0B0B0E").withAlphaComponent(0.80)
        default:
            return UIColor(hex: "#F8F9FD").withAlphaComponent(0.82)
        }
    }

    // MARK: Primary
    static let gpPrimary = dynamic(light: "#5856D6", dark: "#6366F1")
    static let gpPrimaryLight = dynamic(light: "#5856D6", dark: "#8B85FF")
    static let gpAccent = gpPrimary
    static let gpOnPrimary = UIColor.white

    // MARK: Text
    static let gpTextPrimary = dynamic(light: "#1A1A1E", dark: "#FAFAF9")
    static let gpTextSecondary = dynamic(light: "#8E8E93", dark: "#6B6B70")
    static let gpTextTertiary = dynamic(light: "#AEAEB2", dark: "#4A4A50")
    static let gpTextMuted = dynamic(light: "#C7C7CC", dark: "#8E8E93")
    static let gpTextInverse = dynamic(light: "#FFFFFF", dark: "#0B0B0E")

    // MARK: Accent
    static let gpStar = dynamic(light: "#FF9500", dark: "#FFB547")
    static let gpRating = gpStar
    static let gpBadge = dynamic(light: "#3D82D9", dark: "#62A8FF")
    static let gpRed = dynamic(light: "#FF3B30", dark: "#E85A4F")
    static let gpCoral = gpRed
    static let gpOrange = dynamic(light: "#E58B2B", dark: "#FFB14A")
    static let gpTeal = dynamic(light: "#2FA59B", dark: "#4ECDC4")
    static let gpSuccess = dynamic(light: "#34C759", dark: "#32D583")

    // MARK: Separators / Utility
    static let gpSeparator = dynamic(light: "#E5E5EA", dark: "#2A2A2E")
    static let gpBorder = gpSeparator
    static let gpTabBarSeparator = UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor.white.withAlphaComponent(18.0 / 255.0)
        default:
            return UIColor.black.withAlphaComponent(0.08)
        }
    }
    static let gpShadow = UIColor { trait in
        switch trait.userInterfaceStyle {
        case .dark:
            return UIColor.black.withAlphaComponent(0.34)
        default:
            return UIColor.black.withAlphaComponent(0.12)
        }
    }
    static let gpHeroGradientEnd = dynamic(light: "#F8F8FA", dark: "#0B0B0E")
    static let gpSocialButtonBackground = dynamic(light: "#FFFFFF", dark: "#16161A")
    static let gpSocialButtonForeground = dynamic(light: "#1A1A1E", dark: "#FAFAF9")
    static let gpSocialButtonBorder = dynamic(light: "#E5E5EA", dark: "#2A2A2E")
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
