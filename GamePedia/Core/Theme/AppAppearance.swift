import UIKit

enum AppAppearance: String, CaseIterable {
    case dark

    var interfaceStyle: UIUserInterfaceStyle {
        .dark
    }
}

enum AppAppearanceStore {
    static var current: AppAppearance {
        .dark
    }
}

enum AppAppearanceController {
    static func apply(to window: UIWindow?) {
        guard let window else { return }

        window.overrideUserInterfaceStyle = AppAppearanceStore.current.interfaceStyle
        print("[Theme] applied appearance=dark interfaceStyle=\(window.overrideUserInterfaceStyle.rawValue)")
    }
}
