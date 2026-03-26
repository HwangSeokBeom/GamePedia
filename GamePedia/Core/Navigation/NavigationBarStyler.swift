import UIKit

// MARK: - NavigationStyle

enum NavigationStyle {
    /// Standard opaque bar used by most content screens.
    case opaque
    /// Transparent bar used by Game Detail over the hero image.
    case transparent
}

// MARK: - NavigationBarStyler
//
// Single source of truth for all navigation bar appearance settings.
// Coordinators apply per-screen appearances before setViewControllers/pushViewController
// so UIKit builds each transition from the final navigation state.

struct NavigationBarStyler {

    // MARK: Per-Screen Setup

    /// Applies a navigation style to a view controller's own navigationItem.
    /// Always wrap the call site in UIView.performWithoutAnimation.
    static func apply(
        _ style: NavigationStyle,
        to navigationItem: UINavigationItem,
        buttonTintColor: UIColor = .gpTextPrimary
    ) {
        switch style {
        case .opaque:
            let appearance = makeOpaqueAppearance(buttonTintColor: buttonTintColor)
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
            navigationItem.compactAppearance = appearance

        case .transparent:
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
            buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gpOnPrimary]
            appearance.buttonAppearance = buttonAppearance
            appearance.backButtonAppearance = buttonAppearance
            appearance.titleTextAttributes = [.foregroundColor: UIColor.gpOnPrimary]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.gpOnPrimary]
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
            navigationItem.compactAppearance = appearance
        }
    }

    // MARK: Global Bar Setup

    /// Configures the nav bar's global fallback appearance.
    /// Called once per UINavigationController at creation time so every screen
    /// has a stable base even before per-screen overrides are applied.
    static func configureGlobalAppearance(on navigationBar: UINavigationBar) {
        let appearance = makeOpaqueAppearance(buttonTintColor: .gpTextPrimary)
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.prefersLargeTitles = false
        navigationBar.tintColor = .gpTextPrimary
    }

    // MARK: Private

    private static func makeOpaqueAppearance(buttonTintColor: UIColor) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .gpNavigationBarBackground
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.gpTextPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.gpTextPrimary]
        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: buttonTintColor]
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        return appearance
    }
}
