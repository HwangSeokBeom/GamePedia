import Foundation

final class DeleteReviewCommentUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute(commentId: String, context: ReviewDiscussionContext) async throws -> ReviewComment {
        try await repository.deleteComment(commentId: commentId, in: context)
    }
}
