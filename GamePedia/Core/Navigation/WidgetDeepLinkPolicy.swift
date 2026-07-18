import Foundation

// MARK: - WidgetDeepLinkPolicy
//
// Pure routing decision for typed widget/push deep links. AppCoordinator
// previously repeated the same "authenticated? else park the link and
// present auth" block once per session-gated destination; the decision
// now lives here once, deterministic and unit-testable, while the
// coordinator keeps only the side effects (navigation, presentation).
//
// Unknown links never reach this policy: `WidgetDeepLink(url:)` already
// rejects unrecognized schemes/hosts/paths by returning nil, and callers
// treat that as "not handled".

enum WidgetDeepLinkDecision: Equatable {
    /// Execute the destination now.
    case perform
    /// UI is not ready (splash / no main interface): park the link.
    case deferUntilInterfaceReady
    /// Destination is session-gated and there is no authenticated
    /// session: park the link and present authentication first.
    case requireAuthentication
    /// Valid link that is a no-op in the current session state
    /// (e.g. `login` while already authenticated).
    case ignore
}

enum WidgetDeepLinkPolicy {

    static func decision(
        for deepLink: WidgetDeepLink,
        isInterfaceReady: Bool,
        isAuthenticated: Bool
    ) -> WidgetDeepLinkDecision {
        guard isInterfaceReady else { return .deferUntilInterfaceReady }

        switch deepLink {
        case .game, .trending:
            return .perform
        case .profile, .review, .reviewNew:
            return isAuthenticated ? .perform : .requireAuthentication
        case .login:
            return isAuthenticated ? .ignore : .perform
        }
    }
}
