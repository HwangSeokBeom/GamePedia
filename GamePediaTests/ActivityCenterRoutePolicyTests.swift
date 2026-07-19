import XCTest
@testable import GamePedia

// Routing out of the Activity Center must never bypass authentication.
final class ActivityCenterRoutePolicyTests: XCTestCase {

    func test_authenticatedSession_performsEveryRoute() {
        let routes: [SocialActivityRoute] = [
            .friendActivityFeed,
            .friendRequests,
            .friendProfile("u1"),
            .gameDetail(7),
            .review(gameID: 7, reviewID: "r1", commentID: nil)
        ]
        for route in routes {
            XCTAssertEqual(
                ActivityCenterRoutePolicy.decision(for: route, isAuthenticated: true),
                .perform
            )
        }
    }

    func test_guestSession_requiresAuthentication_forFriendSurfaces() {
        XCTAssertEqual(
            ActivityCenterRoutePolicy.decision(for: .friendActivityFeed, isAuthenticated: false),
            .requireAuthentication
        )
        XCTAssertEqual(
            ActivityCenterRoutePolicy.decision(for: .friendRequests, isAuthenticated: false),
            .requireAuthentication
        )
        XCTAssertEqual(
            ActivityCenterRoutePolicy.decision(for: .friendProfile("u1"), isAuthenticated: false),
            .requireAuthentication
        )
    }

    func test_guestSession_performsPublicRoutes() {
        XCTAssertEqual(
            ActivityCenterRoutePolicy.decision(for: .gameDetail(7), isAuthenticated: false),
            .perform
        )
        XCTAssertEqual(
            ActivityCenterRoutePolicy.decision(
                for: .review(gameID: 7, reviewID: "r1", commentID: "c1"),
                isAuthenticated: false
            ),
            .perform
        )
    }
}
