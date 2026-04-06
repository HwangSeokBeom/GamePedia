import Foundation

final class FetchReviewCommentsUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute(context: ReviewDiscussionContext) async throws -> [ReviewComment] {
        try await repository.fetchComments(for: context)
    }
}
