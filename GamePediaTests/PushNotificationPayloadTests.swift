import XCTest
@testable import GamePedia

final class PushNotificationPayloadTests: XCTestCase {
    func testParseGameDetailPayloadRoutesToGameDetail() {
        let payload = PushNotificationPayload.parse(userInfo: [
            "type": "review_liked",
            "notificationId": "notification-1",
            "gameId": "328386",
            "route": "game_detail",
            "source": "push"
        ])

        XCTAssertEqual(payload?.type, "review_liked")
        XCTAssertEqual(payload?.notificationID, "notification-1")
        XCTAssertEqual(payload?.gameID, 328386)
        XCTAssertEqual(payload?.destination, .gameDetail(328386))
    }

    func testParseReviewThreadPayloadRoutesToReviewDetail() {
        let payload = PushNotificationPayload.parse(userInfo: [
            "type": "review_comment_reply",
            "notificationId": "notification-2",
            "gameId": 42,
            "reviewId": "review-42",
            "commentId": "comment-42",
            "route": "review_thread"
        ])

        XCTAssertEqual(
            payload?.destination,
            .reviewDetail(gameID: 42, reviewID: "review-42", commentID: "comment-42")
        )
    }

    func testUnsupportedPayloadFallsBackToNotifications() {
        let payload = PushNotificationPayload.parse(userInfo: [
            "type": "unsupported",
            "notificationId": "notification-3",
            "route": "unsupported_route"
        ])

        XCTAssertEqual(payload?.destination, .notifications)
    }

    func testBadgeParsesFromApsPayload() {
        let payload = PushNotificationPayload.parse(userInfo: [
            "type": "notification_list",
            "aps": ["badge": 7]
        ])

        XCTAssertEqual(payload?.badge, 7)
    }
}
