import Foundation

final class FetchReviewCommentCountsUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute(reviewIds: [String]) async throws -> [String: Int] {
        try await repository.fetchCommentCounts(reviewIds: reviewIds)
    }
}
