import Foundation

struct DeleteReviewUseCase {
    private let reviewRepository: any ReviewRepository

    init(reviewRepository: any ReviewRepository) {
        self.reviewRepository = reviewRepository
    }

    func execute(reviewId: String) async throws -> ReviewDeletionResult {
        try await reviewRepository.deleteReview(reviewId: reviewId)
    }
}
