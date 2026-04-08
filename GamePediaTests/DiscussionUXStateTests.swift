import XCTest
@testable import GamePedia

final class DiscussionUXStateTests: XCTestCase {
    func testGameDetailPreviewReviews_backfillsToFiveWhenCommunityReviewsAreInsufficient() {
        var state = GameDetailState()
        state.reviews = (0..<6).map { index in
            makeReview(
                id: "review-\(index)",
                authorId: "author-\(index)",
                isMine: index < 3,
                commentCount: index
            )
        }

        XCTAssertEqual(state.previewReviews.count, 5)
        XCTAssertEqual(state.myReviews.count, 3)
        XCTAssertEqual(state.communityPreviewReviews.count, 3)
        XCTAssertEqual(state.previewReviews.map(\.id), [
            "review-3",
            "review-4",
            "review-5",
            "review-0",
            "review-1"
        ])
        XCTAssertEqual(state.writeReviewButtonTitle, L10n.tr("Localizable", "detail.button.writeAnotherReview"))
    }

    func testGameDetailCommunityPreviewReviews_limitsToFiveItems() {
        var state = GameDetailState()
        state.reviews = (0..<7).map { index in
            makeReview(
                id: "community-review-\(index)",
                authorId: "community-author-\(index)",
                isMine: false,
                commentCount: index
            )
        }

        XCTAssertEqual(state.communityPreviewReviews.count, GameDetailState.reviewPreviewLimit)
        XCTAssertEqual(state.communityPreviewReviews.map(\.id), [
            "community-review-0",
            "community-review-1",
            "community-review-2",
            "community-review-3",
            "community-review-4"
        ])
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

    func testReviewDiscussionSectionState_ignoresDeletedCommentsForEmptyState() {
        var state = ReviewDiscussionState(
            gameId: 10,
            initialGameTitle: "테스트 게임",
            reviewId: "review-3"
        )
        state.review = makeReview(id: "review-3", authorId: "author-1", isMine: false, commentCount: 1)
        state.comments = [
            ReviewComment(
                id: "deleted-comment",
                reviewId: "review-3",
                gameId: 10,
                gameTitle: "테스트 게임",
                reviewSnippet: "리뷰 내용",
                parentCommentId: nil,
                depth: 0,
                author: ReviewCommentAuthor(
                    id: "user-deleted",
                    nickname: "작성자",
                    profileImageUrl: nil
                ),
                content: L10n.tr("Localizable", "review.comment.deletedPlaceholder"),
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 2),
                isMine: true,
                isReviewAuthor: false,
                isDeleted: true,
                isEdited: false,
                replyCount: 0,
                likeCount: 0,
                dislikeCount: 0,
                myReaction: nil
            )
        ]

        XCTAssertEqual(state.totalDiscussionCount, 0)
        XCTAssertEqual(state.discussionContentState, .empty)
        XCTAssertEqual(state.emptyStateActionTitle, L10n.tr("Localizable", "review.comment.empty.cta"))
    }

    func testReviewDiscussionReducer_setComposerModePreservingText_keepsDraftWhileNormalizingMode() {
        var state = ReviewDiscussionState(
            gameId: 10,
            initialGameTitle: "테스트 게임",
            reviewId: "review-4"
        )
        state.composerText = "답글 초안"
        state.composerMode = .reply(.init(
            parentCommentId: "comment-1",
            targetCommentId: "comment-1",
            targetNickname: "작성자",
            targetPreviewText: "원본 댓글",
            isSelfReply: false
        ))

        let reducedState = ReviewDiscussionReducer.reduce(
            state,
            .setComposerModePreservingText(.comment)
        )

        XCTAssertEqual(reducedState.composerText, "답글 초안")
        XCTAssertEqual(reducedState.composerMode, .comment)
    }

    func testReviewCommentActionSheetModel_usesMyCommentActions() {
        let model = ReviewCommentActionSheetModel(
            commentId: "comment-1",
            reviewId: "review-1",
            authorId: "me",
            authorNickname: "나",
            authorProfileImageUrl: nil,
            content: "내 댓글",
            createdAt: Date(),
            likeCount: 2,
            isReply: false,
            parentCommentId: nil,
            isOwnedByCurrentUser: true
        )

        XCTAssertEqual(model.actionKinds, [.reply, .edit, .delete])
        XCTAssertEqual(model.title, L10n.tr("Localizable", "review.comment.sheet.mineTitle"))
    }

    func testReviewCommentActionSheetModel_usesOtherCommentActions() {
        let model = ReviewCommentActionSheetModel(
            commentId: "comment-2",
            reviewId: "review-1",
            authorId: "other",
            authorNickname: "다른 유저",
            authorProfileImageUrl: nil,
            content: "남의 댓글",
            createdAt: Date(),
            likeCount: 3,
            isReply: true,
            parentCommentId: "comment-1",
            isOwnedByCurrentUser: false
        )

        XCTAssertEqual(model.actionKinds, [.reply, .report])
        XCTAssertEqual(model.title, L10n.tr("Localizable", "review.comment.sheet.otherTitle", "다른 유저"))
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
