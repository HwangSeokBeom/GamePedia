import XCTest
@testable import GamePedia

// Deterministic routing decisions: session gating, interface-readiness
// deferral, and login no-op. Unknown-link safety lives in
// WidgetDeepLinkParserTests (the parser rejects unknown URLs before any
// policy decision is made).
final class WidgetDeepLinkPolicyTests: XCTestCase {

    private let allLinks: [WidgetDeepLink] = [
        .game(1), .trending, .profile, .login, .review("r1"), .reviewNew(2)
    ]

    func test_interfaceNotReady_defersEveryLink() {
        for link in allLinks {
            for isAuthenticated in [true, false] {
                XCTAssertEqual(
                    WidgetDeepLinkPolicy.decision(
                        for: link,
                        isInterfaceReady: false,
                        isAuthenticated: isAuthenticated
                    ),
                    .deferUntilInterfaceReady,
                    "link \(link) must be parked while the interface is not ready"
                )
            }
        }
    }

    func test_publicDestinations_performWithoutSession() {
        for link in [WidgetDeepLink.game(1), .trending] {
            XCTAssertEqual(
                WidgetDeepLinkPolicy.decision(for: link, isInterfaceReady: true, isAuthenticated: false),
                .perform
            )
            XCTAssertEqual(
                WidgetDeepLinkPolicy.decision(for: link, isInterfaceReady: true, isAuthenticated: true),
                .perform
            )
        }
    }

    func test_sessionGatedDestinations_requireAuthentication() {
        for link in [WidgetDeepLink.profile, .review("r1"), .reviewNew(2)] {
            XCTAssertEqual(
                WidgetDeepLinkPolicy.decision(for: link, isInterfaceReady: true, isAuthenticated: false),
                .requireAuthentication,
                "unauthenticated \(link) must gate through auth"
            )
            XCTAssertEqual(
                WidgetDeepLinkPolicy.decision(for: link, isInterfaceReady: true, isAuthenticated: true),
                .perform
            )
        }
    }

    func test_login_performsOnlyForGuests() {
        XCTAssertEqual(
            WidgetDeepLinkPolicy.decision(for: .login, isInterfaceReady: true, isAuthenticated: false),
            .perform
        )
        XCTAssertEqual(
            WidgetDeepLinkPolicy.decision(for: .login, isInterfaceReady: true, isAuthenticated: true),
            .ignore,
            "login link while authenticated must be a no-op"
        )
    }
}
