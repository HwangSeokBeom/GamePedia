import Foundation

final class UpdateReviewCommentUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute(commentId: String, content: String, context: ReviewDiscussionContext) async throws -> ReviewComment {
        try await repository.updateComment(commentId: commentId, content: content, in: context)
    }
}
