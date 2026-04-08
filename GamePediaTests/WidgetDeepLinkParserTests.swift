import XCTest
@testable import GamePedia

final class WidgetDeepLinkParserTests: XCTestCase {

    func testInit_parsesSupportedWidgetRoutes() {
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://game/42")!), .game(42))
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://trending")!), .trending)
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://login")!), .login)
        XCTAssertEqual(WidgetDeepLink(url: URL(string: "gamepedia://review/new/128")!), .reviewNew(128))
    }

    func testInit_rejectsUnsupportedOrLegacyRoutes() {
        XCTAssertNil(WidgetDeepLink(url: URL(string: "gamepedia://review/abc")!))
        XCTAssertNil(WidgetDeepLink(url: URL(string: "gamepedia://review/123")!))
        XCTAssertNil(WidgetDeepLink(url: URL(string: "https://example.com/game/42")!))
    }

    func testURL_buildsExpectedRouteStrings() {
        XCTAssertEqual(WidgetDeepLink.game(7).url.absoluteString, "gamepedia://game/7")
        XCTAssertEqual(WidgetDeepLink.trending.url.absoluteString, "gamepedia://trending")
        XCTAssertEqual(WidgetDeepLink.login.url.absoluteString, "gamepedia://login")
        XCTAssertEqual(WidgetDeepLink.reviewNew(99).url.absoluteString, "gamepedia://review/new/99")
    }
}
