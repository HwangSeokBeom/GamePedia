import Foundation

struct UpdateReviewUseCase {
    private let reviewRepository: any ReviewRepository

    init(reviewRepository: any ReviewRepository) {
        self.reviewRepository = reviewRepository
    }

    func execute(reviewId: String, rating: Double?, content: String?) async throws -> Review {
        print("[ReviewSubmit] UpdateReviewUseCase.execute reviewId=\(reviewId) rating=\(rating?.description ?? "nil") trimmedCount=\(content?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0)")
        return try await reviewRepository.updateReview(reviewId: reviewId, rating: rating, content: content)
    }
}
