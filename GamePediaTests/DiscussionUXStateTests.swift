import XCTest
@testable import GamePedia

final class DiscussionUXStateTests: XCTestCase {
    func testGameDetailPreviewReviews_limitsToFiveItems() {
        var state = GameDetailState()
        state.reviews = (0..<7).map { index in
            makeReview(
                id: "review-\(index)",
                authorId: "author-\(index)",
                isMine: index < 6,
                commentCount: index
            )
        }

        XCTAssertEqual(state.previewReviews.count, 5)
        XCTAssertEqual(state.communityPreviewReviews.count, 1)
        XCTAssertEqual(state.writeReviewButtonTitle, L10n.tr("Localizable", "detail.button.writeAnotherReview"))
    }

    func testReviewDiscussionSectionState_usesMergedDiscussionCountForEmptyCTA() {
        var state = ReviewDiscussionState(
            gameId: 10,
            initialGameTitle: "테스트 게임",
            reviewId: "review-1"
        )
        state.review = makeReview(id: "review-1", authorId: "author-1", isMine: false, commentCount: 2)

        XCTAssertEqual(state.discussionSectionState?.commentCount, 2)
        XCTAssertEqual(state.emptyStateActionTitle, L10n.tr("Localizable", "review.comment.empty.nonEmptyCta"))
    }

    func testReviewDiscussionSectionState_countsRepliesInLocalDiscussionState() {
        var state = ReviewDiscussionState(
            gameId: 10,
            initialGameTitle: "테스트 게임",
            reviewId: "review-2"
        )
        state.review = makeReview(id: "review-2", authorId: "author-1", isMine: false, commentCount: 0)
        state.comments = [
            makeComment(id: "comment-1", parentCommentId: nil, depth: 0, likeCount: 0),
            makeComment(id: "comment-2", parentCommentId: "comment-1", depth: 1, likeCount: 1)
        ]

        XCTAssertEqual(state.totalDiscussionCount, 2)
        XCTAssertEqual(state.discussionSectionState?.commentCount, 2)
        XCTAssertEqual(state.emptyStateActionTitle, L10n.tr("Localizable", "review.comment.empty.nonEmptyCta"))
    }

    private func makeReview(id: String, authorId: String, isMine: Bool, commentCount: Int) -> Review {
        Review(
            id: id,
            gameId: "game-1",
            rating: 4.5,
            content: "리뷰 내용",
            createdAt: "2026-04-07T00:00:00Z",
            updatedAt: "2026-04-07T00:00:00Z",
            author: ReviewAuthor(
                id: authorId,
                nickname: "작성자",
                profileImageUrl: nil
            ),
            isMine: isMine,
            likeCount: 0,
            commentCount: commentCount,
            isLikedByCurrentUser: false
        )
    }

    private func makeComment(id: String, parentCommentId: String?, depth: Int, likeCount: Int) -> ReviewComment {
        ReviewComment(
            id: id,
            reviewId: "review-2",
            gameId: 10,
            gameTitle: "테스트 게임",
            reviewSnippet: "리뷰 내용",
            parentCommentId: parentCommentId,
            depth: depth,
            author: ReviewCommentAuthor(
                id: "user-\(id)",
                nickname: "작성자",
                profileImageUrl: nil
            ),
            content: "댓글 내용",
            createdAt: Date(timeIntervalSince1970: depth == 0 ? 1 : 2),
            updatedAt: nil,
            isMine: false,
            isReviewAuthor: false,
            isDeleted: false,
            isEdited: false,
            replyCount: 0,
            likeCount: likeCount,
            dislikeCount: 0,
            myReaction: nil
        )
    }
}
