import Foundation

final class ReactToStoredReviewCommentUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute(commentId: String, reaction: ReviewCommentReaction?) async throws -> ReviewComment {
        try await repository.react(to: commentId, reaction: reaction)
    }
}
