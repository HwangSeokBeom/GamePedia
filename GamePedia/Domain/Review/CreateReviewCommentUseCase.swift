import Foundation

final class CreateReviewCommentUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute(draft: ReviewCommentDraft, context: ReviewDiscussionContext) async throws -> ReviewComment {
        try await repository.createComment(draft: draft, in: context)
    }
}
