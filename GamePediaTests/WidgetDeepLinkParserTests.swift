import XCTest
@testable import GamePedia

final class WidgetDeepLinkParserTests: XCTestCase {

    func testInit_parsesSupportedWidgetRoutes() {
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://game/42")!), .game(42))
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://trending")!), .trending)
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://profile")!), .profile)
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://login")!), .login)
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://review/rev-128")!), .review("rev-128"))
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://review/new/128")!), .reviewNew(128))
    }

    func testInit_rejectsUnsupportedOrLegacyRoutes() {
        XCTAssertNil(WidgetDeepLink(url: URL(string: "gamepedia://review")!))
        XCTAssertNil(WidgetDeepLink(url: URL(string: "https://example.com/game/42")!))
    }

    func testURL_buildsExpectedRouteStrings() {
        XCTAssertEqual(WidgetDeepLink.game(7).url.absoluteString, "gamepedia://game/7")
        XCTAssertEqual(WidgetDeepLink.trending.url.absoluteString, "gamepedia://trending")
        XCTAssertEqual(WidgetDeepLink.profile.url.absoluteString, "gamepedia://profile")
        XCTAssertEqual(WidgetDeepLink.login.url.absoluteString, "gamepedia://login")
        XCTAssertEqual(WidgetDeepLink.review("r-1").url.absoluteString, "gamepedia://review/r-1")
        XCTAssertEqual(WidgetDeepLink.reviewNew(99).url.absoluteString, "gamepedia://review/new/99")
    }
}
