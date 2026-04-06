import Foundation

final class ReactToReviewCommentUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute(commentId: String, reaction: ReviewCommentReaction?, context: ReviewDiscussionContext) async throws -> ReviewComment {
        try await repository.react(to: commentId, reaction: reaction, in: context)
    }
}
