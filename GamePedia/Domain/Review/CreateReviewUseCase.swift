import Foundation

struct CreateReviewUseCase {
    private let reviewRepository: any ReviewRepository

    init(reviewRepository: any ReviewRepository) {
        self.reviewRepository = reviewRepository
    }

    func execute(gameId: String, rating: Double, content: String) async throws -> Review {
        print("[ReviewSubmit] CreateReviewUseCase.execute gameId=\(gameId) rating=\(rating) trimmedCount=\(content.trimmingCharacters(in: .whitespacesAndNewlines).count)")
        return try await reviewRepository.createReview(gameId: gameId, rating: rating, content: content)
    }
}
