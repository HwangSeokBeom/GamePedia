import Foundation

final class DefaultReviewCommentRepository: ReviewCommentRepository {
    private let localDataSource: any ReviewCommentLocalDataSource
    private let userSessionStore: any UserSessionStore

    init(
        localDataSource: any ReviewCommentLocalDataSource = DefaultReviewCommentLocalDataSource(),
        userSessionStore: any UserSessionStore = InMemoryUserSessionStore.shared
    ) {
        self.localDataSource = localDataSource
        self.userSessionStore = userSessionStore
    }

    func fetchComments(for context: ReviewDiscussionContext) async throws -> [ReviewComment] {
        try localDataSource.fetchComments(for: context, currentUser: userSessionStore.fetchUser())
    }

    func createComment(draft: ReviewCommentDraft, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.createComment(draft: draft, in: context, currentUser: currentUser)
        ReviewCommentSyncCenter.send(
            ReviewCommentSyncEvent(
                action: .created,
                reviewId: context.reviewId,
                gameId: context.gameId,
                commentId: comment.id,
                comment: comment
            )
        )
        return comment
    }

    func updateComment(commentId: String, content: String, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.updateComment(commentId: commentId, content: content, in: context, currentUser: currentUser)
        ReviewCommentSyncCenter.send(
            ReviewCommentSyncEvent(
                action: .updated,
                reviewId: context.reviewId,
                gameId: context.gameId,
                commentId: comment.id,
                comment: comment
            )
        )
        return comment
    }

    func deleteComment(commentId: String, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.deleteComment(commentId: commentId, in: context, currentUser: currentUser)
        ReviewCommentSyncCenter.send(
            ReviewCommentSyncEvent(
                action: .deleted,
                reviewId: context.reviewId,
                gameId: context.gameId,
                commentId: comment.id,
                comment: comment
            )
        )
        return comment
    }

    func react(to commentId: String, reaction: ReviewCommentReaction?, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.react(to: commentId, reaction: reaction, in: context, currentUser: currentUser)
        ReviewCommentSyncCenter.send(
            ReviewCommentSyncEvent(
                action: .reacted,
                reviewId: context.reviewId,
                gameId: context.gameId,
                commentId: comment.id,
                comment: comment
            )
        )
        return comment
    }

    func react(to commentId: String, reaction: ReviewCommentReaction?) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.react(to: commentId, reaction: reaction, currentUser: currentUser)
        ReviewCommentSyncCenter.send(
            ReviewCommentSyncEvent(
                action: .reacted,
                reviewId: comment.reviewId,
                gameId: comment.gameId,
                commentId: comment.id,
                comment: comment
            )
        )
        return comment
    }

    func fetchCommentCounts(reviewIds: [String]) async throws -> [String: Int] {
        try localDataSource.fetchCommentCounts(reviewIds: reviewIds)
    }

    func fetchMyComments() async throws -> [MyReviewCommentEntry] {
        try localDataSource.fetchMyComments(currentUser: userSessionStore.fetchUser())
    }

    func fetchLocalNotifications() async -> [AppNotification] {
        (try? localDataSource.fetchNotifications()) ?? []
    }

    func markAllLocalNotificationsRead() async {
        try? localDataSource.markAllNotificationsRead()
    }

}
