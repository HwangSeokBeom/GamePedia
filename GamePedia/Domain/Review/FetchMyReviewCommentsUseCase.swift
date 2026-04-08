import Foundation

final class FetchMyReviewCommentsUseCase {
    private let repository: any ReviewCommentRepository

    init(repository: any ReviewCommentRepository) {
        self.repository = repository
    }

    func execute() async throws -> [MyReviewCommentEntry] {
        try await repository.fetchMyComments()
    }
}
