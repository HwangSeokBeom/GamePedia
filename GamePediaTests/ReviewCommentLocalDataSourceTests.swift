import XCTest
@testable import GamePedia

final class ReviewCommentLocalDataSourceTests: XCTestCase {
    private var userDefaultsSuiteName: String!
    private var userDefaults: UserDefaults!
    private var dataSource: DefaultReviewCommentLocalDataSource!

    override func setUp() {
        super.setUp()
        userDefaultsSuiteName = "ReviewCommentLocalDataSourceTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        dataSource = DefaultReviewCommentLocalDataSource(userDefaults: userDefaults)
    }

    override func tearDown() {
        if let userDefaultsSuiteName {
            userDefaults?.removePersistentDomain(forName: userDefaultsSuiteName)
        }
        dataSource = nil
        userDefaults = nil
        userDefaultsSuiteName = nil
        super.tearDown()
    }

    func testFetchComments_sortsNewestThreadFirstAndNormalizesReplyDepth() throws {
        let reviewAuthor = makeUser(id: "review-author", nickname: "리뷰작성자")
        let replyingUser = makeUser(id: "reply-user", nickname: "답글유저")
        let context = makeContext(reviewAuthor: reviewAuthor)

        let olderRootComment = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: nil, content: "older-root"),
            in: context,
            currentUser: reviewAuthor
        )

        Thread.sleep(forTimeInterval: 0.02)

        let firstReply = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: olderRootComment.id, content: "first-reply"),
            in: context,
            currentUser: replyingUser
        )

        Thread.sleep(forTimeInterval: 0.02)

        let secondReply = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: firstReply.id, content: "reply-to-reply"),
            in: context,
            currentUser: replyingUser
        )

        Thread.sleep(forTimeInterval: 0.02)

        let newerRootComment = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: nil, content: "newer-root"),
            in: context,
            currentUser: replyingUser
        )

        let comments = try dataSource.fetchComments(for: context, currentUser: replyingUser)

        XCTAssertEqual(comments.map(\.id), [
            newerRootComment.id,
            olderRootComment.id,
            firstReply.id,
            secondReply.id
        ])

        let olderThreadReplies = comments.filter { $0.parentCommentId == olderRootComment.id }
        XCTAssertEqual(olderThreadReplies.map(\.id), [firstReply.id, secondReply.id])
        XCTAssertTrue(olderThreadReplies.allSatisfy { $0.depth == 1 })
        XCTAssertEqual(olderThreadReplies.first?.parentCommentId, olderRootComment.id)
        XCTAssertEqual(olderThreadReplies.last?.parentCommentId, olderRootComment.id)
        XCTAssertEqual(comments.first(where: { $0.id == olderRootComment.id })?.replyCount, 2)
        XCTAssertTrue(comments.first(where: { $0.id == olderRootComment.id })?.isReviewAuthor == true)
    }

    func testFetchMyComments_returnsDeletedPlaceholderFromSharedCommentEntity() throws {
        let currentUser = makeUser(id: "current-user", nickname: "내계정")
        let context = makeContext(reviewAuthor: currentUser)

        let createdComment = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: nil, content: "my-comment"),
            in: context,
            currentUser: currentUser
        )

        _ = try dataSource.react(
            to: createdComment.id,
            reaction: .like,
            in: context,
            currentUser: currentUser
        )

        let deletedComment = try dataSource.deleteComment(
            commentId: createdComment.id,
            in: context,
            currentUser: currentUser
        )

        let items = try dataSource.fetchMyComments(currentUser: currentUser)
        let item = try XCTUnwrap(items.first)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(item.id, deletedComment.id)
        XCTAssertEqual(item.comment.id, deletedComment.id)
        XCTAssertEqual(item.commentContent, L10n.tr("Localizable", "review.comment.deletedPlaceholder"))
        XCTAssertEqual(item.gameTitle, context.gameTitle)
        XCTAssertEqual(item.reviewSnippet, context.reviewSnippet)
        XCTAssertEqual(item.likeCount, 1)
        XCTAssertEqual(item.myReaction, .like)
        XCTAssertTrue(item.isMine)
        XCTAssertTrue(item.isReviewAuthor)
        XCTAssertTrue(item.isDeleted)
        XCTAssertEqual(item.formattedDate, item.comment.formattedDate)
    }

    func testNotifications_areCreatedForOtherUsersReplyAndReaction() throws {
        let commentAuthor = makeUser(id: "comment-author", nickname: "작성자")
        let otherUser = makeUser(id: "other-user", nickname: "다른유저")
        let context = makeContext(reviewAuthor: commentAuthor)

        let rootComment = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: nil, content: "root-comment"),
            in: context,
            currentUser: commentAuthor
        )

        let reply = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: rootComment.id, content: "reply"),
            in: context,
            currentUser: otherUser
        )

        _ = try dataSource.react(
            to: rootComment.id,
            reaction: .like,
            in: context,
            currentUser: otherUser
        )

        let notifications = try dataSource.fetchNotifications()

        XCTAssertEqual(notifications.count, 2)
        XCTAssertEqual(notifications.first?.relatedCommentID, rootComment.id)
        XCTAssertEqual(notifications.last?.relatedCommentID, reply.id)
    }

    func testFetchCommentCounts_includesRepliesAndDeletedComments() throws {
        let reviewAuthor = makeUser(id: "review-author", nickname: "리뷰작성자")
        let otherUser = makeUser(id: "reply-user", nickname: "답글유저")
        let context = makeContext(reviewAuthor: reviewAuthor)

        let rootComment = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: nil, content: "root-comment"),
            in: context,
            currentUser: reviewAuthor
        )

        _ = try dataSource.createComment(
            draft: ReviewCommentDraft(parentCommentId: rootComment.id, content: "reply-comment"),
            in: context,
            currentUser: otherUser
        )

        _ = try dataSource.deleteComment(
            commentId: rootComment.id,
            in: context,
            currentUser: reviewAuthor
        )

        let counts = try dataSource.fetchCommentCounts(reviewIds: [context.reviewId])
        XCTAssertEqual(counts[context.reviewId], 2)
    }

    private func makeContext(reviewAuthor: AuthUser) -> ReviewDiscussionContext {
        let review = Review(
            id: "review-id",
            gameId: "game-id",
            rating: 4.5,
            content: "리뷰 본문 일부",
            createdAt: "2026-04-06T00:00:00Z",
            updatedAt: "2026-04-06T00:00:00Z",
            author: ReviewAuthor(
                id: reviewAuthor.id,
                nickname: reviewAuthor.nickname,
                profileImageUrl: reviewAuthor.profileImageUrl
            ),
            isMine: reviewAuthor.id == "current-user",
            likeCount: 0,
            commentCount: 0,
            isLikedByCurrentUser: false
        )

        return ReviewDiscussionContext(
            gameId: 100,
            gameTitle: "테스트 게임",
            review: review
        )
    }

    private func makeUser(id: String, nickname: String) -> AuthUser {
        AuthUser(
            id: id,
            email: "\(id)@example.com",
            nickname: nickname,
            profileImageUrl: nil,
            status: "active"
        )
    }
}
