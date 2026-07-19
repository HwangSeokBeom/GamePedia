import Foundation

// MARK: - Activity Center route gating
//
// Pure decision table, mirroring WidgetDeepLinkPolicy: routing out of the
// Activity Center must never bypass authentication. Session-gated
// destinations (friend surfaces) require an authenticated session; public
// destinations (game detail, review threads) always perform. Extracted as
// pure logic so the invariant is directly testable.

enum ActivityCenterRouteDecision: Equatable {
    case perform
    case requireAuthentication
}

enum ActivityCenterRoutePolicy {

    static func decision(
        for route: SocialActivityRoute,
        isAuthenticated: Bool
    ) -> ActivityCenterRouteDecision {
        guard isAuthenticated == false else { return .perform }

        switch route {
        case .gameDetail, .review:
            return .perform
        case .friendActivityFeed, .friendRequests, .friendProfile:
            return .requireAuthentication
        }
    }
}
