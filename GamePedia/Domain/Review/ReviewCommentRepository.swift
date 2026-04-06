import Foundation

protocol ReviewCommentRepository {
    func fetchComments(for context: ReviewDiscussionContext) async throws -> [ReviewComment]
    func createComment(draft: ReviewCommentDraft, in context: ReviewDiscussionContext) async throws -> ReviewComment
    func updateComment(commentId: String, content: String, in context: ReviewDiscussionContext) async throws -> ReviewComment
    func deleteComment(commentId: String, in context: ReviewDiscussionContext) async throws -> ReviewComment
    func react(to commentId: String, reaction: ReviewCommentReaction?, in context: ReviewDiscussionContext) async throws -> ReviewComment
    func fetchMyComments() async throws -> [MyReviewCommentEntry]
    func fetchLocalNotifications() async -> [AppNotification]
    func markAllLocalNotificationsRead() async
}
