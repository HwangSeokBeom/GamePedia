import XCTest
@testable import GamePedia

final class HomeCoordinatorTests: XCTestCase {

    func testNavigateToReviewDiscussion_sameTargetDoesNotPushDuplicate() {
        let coordinator = HomeCoordinator()
        coordinator.start()

        coordinator.navigateToReviewDiscussion(gameID: 42, reviewID: "review-42", commentID: nil)
        coordinator.navigateToReviewDiscussion(gameID: 42, reviewID: "review-42", commentID: nil)

        let discussions = coordinator.navigationController.viewControllers.compactMap { $0 as? ReviewDiscussionViewController }

        XCTAssertEqual(discussions.count, 1)
        XCTAssertEqual(coordinator.navigationController.viewControllers.count, 2)
        XCTAssertEqual(discussions.first?.gameId, 42)
        XCTAssertEqual(discussions.first?.reviewId, "review-42")
    }

    func testNavigateToReviewDiscussion_reusesExistingControllerInStack() {
        let coordinator = HomeCoordinator()
        coordinator.start()

        coordinator.navigateToReviewDiscussion(gameID: 12, reviewID: "review-12", commentID: nil)
        let existingDiscussion = coordinator.navigationController.topViewController as? ReviewDiscussionViewController
        XCTAssertNotNil(existingDiscussion)

        let placeholderViewController = UIViewController()
        coordinator.navigationController.setViewControllers(
            coordinator.navigationController.viewControllers + [placeholderViewController],
            animated: false
        )
        coordinator.navigateToReviewDiscussion(gameID: 12, reviewID: "review-12", commentID: nil)

        let discussions = coordinator.navigationController.viewControllers.compactMap { $0 as? ReviewDiscussionViewController }

        XCTAssertEqual(discussions.count, 1)
        XCTAssertTrue(discussions.first === existingDiscussion)
        XCTAssertEqual(discussions.first?.gameId, 12)
        XCTAssertEqual(discussions.first?.reviewId, "review-12")
    }

    func testNavigateToReviewDiscussion_preservesInitialGameTitle() {
        let coordinator = HomeCoordinator()
        coordinator.start()

        coordinator.navigateToReviewDiscussion(
            gameID: 77,
            reviewID: "review-77",
            commentID: nil,
            gameTitle: "Silly Survivors"
        )

        let discussion = coordinator.navigationController.topViewController as? ReviewDiscussionViewController

        XCTAssertEqual(discussion?.gameId, 77)
        XCTAssertEqual(discussion?.reviewId, "review-77")
        XCTAssertEqual(discussion?.initialGameTitle, "Silly Survivors")
    }

    func testReplyDetailRequest_pushesFocusedDiscussionRoute() throws {
        let coordinator = HomeCoordinator()
        coordinator.start()

        coordinator.navigateToReviewDiscussion(
            gameID: 42,
            reviewID: "review-42",
            commentID: nil,
            gameTitle: "Silly Survivors"
        )
        let baseDiscussion = try XCTUnwrap(
            coordinator.navigationController.topViewController as? ReviewDiscussionViewController
        )

        baseDiscussion.onReplyDetailRequested?(
            Self.makeComment(id: "root-comment"),
            Self.makeReview(id: "review-42")
        )

        let discussions = coordinator.navigationController.viewControllers.compactMap { $0 as? ReviewDiscussionViewController }
        let focusedDiscussion = try XCTUnwrap(
            coordinator.navigationController.topViewController as? ReviewDiscussionViewController
        )

        XCTAssertEqual(discussions.count, 2)
        XCTAssertFalse(focusedDiscussion === baseDiscussion)
        XCTAssertEqual(focusedDiscussion.initialGameTitle, "Silly Survivors")
        XCTAssertEqual(focusedDiscussion.initialHighlightCommentId, "root-comment")
        XCTAssertEqual(focusedDiscussion.initialReplyTargetCommentId, "root-comment")
    }

    func testReplyDetailRequest_sameFocusedRouteDoesNotPushDuplicate() throws {
        let coordinator = HomeCoordinator()
        coordinator.start()

        coordinator.navigateToReviewDiscussion(
            gameID: 42,
            reviewID: "review-42",
            commentID: nil,
            gameTitle: "Silly Survivors"
        )
        let baseDiscussion = try XCTUnwrap(
            coordinator.navigationController.topViewController as? ReviewDiscussionViewController
        )
        let comment = Self.makeComment(id: "reply-comment")
        let review = Self.makeReview(id: "review-42")

        baseDiscussion.onReplyDetailRequested?(comment, review)
        let focusedDiscussion = try XCTUnwrap(
            coordinator.navigationController.topViewController as? ReviewDiscussionViewController
        )

        baseDiscussion.onReplyDetailRequested?(comment, review)

        let discussions = coordinator.navigationController.viewControllers.compactMap { $0 as? ReviewDiscussionViewController }

        XCTAssertEqual(discussions.count, 2)
        XCTAssertTrue(coordinator.navigationController.topViewController === focusedDiscussion)
        XCTAssertEqual(focusedDiscussion.initialHighlightCommentId, "reply-comment")
        XCTAssertEqual(focusedDiscussion.initialReplyTargetCommentId, "reply-comment")
    }

    private static func makeReview(id: String) -> Review {
        Review(
            id: id,
            gameId: "42",
            rating: 4.5,
            content: "content",
            createdAt: "2026-04-09T00:00:00Z",
            updatedAt: "2026-04-09T00:00:00Z",
            author: ReviewAuthor(
                id: "author-1",
                nickname: "Tester",
                profileImageUrl: nil
            ),
            isMine: false,
            likeCount: 0,
            commentCount: 1,
            isLikedByCurrentUser: false
        )
    }

    private static func makeComment(id: String) -> ReviewComment {
        ReviewComment(
            id: id,
            reviewId: "review-42",
            gameId: 42,
            gameTitle: "Silly Survivors",
            reviewSnippet: "snippet",
            parentCommentId: nil,
            depth: 0,
            author: ReviewCommentAuthor(
                id: "author-1",
                nickname: "Tester",
                profileImageUrl: nil
            ),
            content: "reply content",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: nil,
            isMine: false,
            isReviewAuthor: false,
            isDeleted: false,
            isEdited: false,
            replyCount: 0,
            likeCount: 0,
            dislikeCount: 0,
            myReaction: nil
        )
    }
}
