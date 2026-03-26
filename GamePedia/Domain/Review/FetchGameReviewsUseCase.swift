import Foundation

struct FetchGameReviewsUseCase {
    private let reviewRepository: any ReviewRepository

    init(reviewRepository: any ReviewRepository) {
        self.reviewRepository = reviewRepository
    }

    func execute(gameId: String, sort: ReviewSortOption? = nil) async throws -> GameReviewFeed {
        try await reviewRepository.fetchGameReviews(gameId: gameId, sort: sort)
    }
}
