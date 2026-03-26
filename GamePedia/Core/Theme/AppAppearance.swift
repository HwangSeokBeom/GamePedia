import UIKit

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    static let userDefaultsKey = "appAppearancePreference"

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppAppearanceStore {
    private static let defaults = UserDefaults.standard

    static var current: AppAppearance {
        get {
            guard let rawValue = defaults.string(forKey: AppAppearance.userDefaultsKey),
                  let appearance = AppAppearance(rawValue: rawValue) else {
                return .system
            }
            return appearance
        }
        set {
            defaults.set(newValue.rawValue, forKey: AppAppearance.userDefaultsKey)
        }
    }
}

enum AppAppearanceController {
    static func apply(to window: UIWindow?) {
        guard let window else { return }

        let appearance = AppAppearanceStore.current
        window.overrideUserInterfaceStyle = appearance.interfaceStyle
        print("[Theme] applied appearance=\(appearance.rawValue) interfaceStyle=\(window.overrideUserInterfaceStyle.rawValue)")
    }
}
