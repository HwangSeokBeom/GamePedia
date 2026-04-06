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
        notifyCommentChange(context: context, commentId: comment.id, action: .created)
        return comment
    }

    func updateComment(commentId: String, content: String, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.updateComment(commentId: commentId, content: content, in: context, currentUser: currentUser)
        notifyCommentChange(context: context, commentId: comment.id, action: .updated)
        return comment
    }

    func deleteComment(commentId: String, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.deleteComment(commentId: commentId, in: context, currentUser: currentUser)
        notifyCommentChange(context: context, commentId: comment.id, action: .deleted)
        return comment
    }

    func react(to commentId: String, reaction: ReviewCommentReaction?, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        guard let currentUser = userSessionStore.fetchUser() else {
            throw ReviewCommentError.unauthorized
        }
        let comment = try localDataSource.react(to: commentId, reaction: reaction, in: context, currentUser: currentUser)
        notifyCommentChange(context: context, commentId: comment.id, action: .reacted)
        return comment
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

    private func notifyCommentChange(context: ReviewDiscussionContext, commentId: String, action: ReviewCommentChangeAction) {
        NotificationCenter.default.post(
            name: .reviewCommentsDidChange,
            object: nil,
            userInfo: [
                ReviewCommentChangeUserInfoKey.reviewId: context.reviewId,
                ReviewCommentChangeUserInfoKey.commentId: commentId,
                ReviewCommentChangeUserInfoKey.gameId: context.gameId,
                ReviewCommentChangeUserInfoKey.action: action.rawValue
            ]
        )
    }
}
