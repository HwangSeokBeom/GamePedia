import Foundation

protocol ReviewRepository {
    func createReview(gameId: String, rating: Double, content: String) async throws -> Review
    func fetchGameReviews(gameId: String, sort: ReviewSortOption?) async throws -> GameReviewFeed
    func updateReview(reviewId: String, rating: Double?, content: String?) async throws -> Review
    func deleteReview(reviewId: String) async throws -> ReviewDeletionResult
    func fetchMyReviews(sort: ReviewSortOption?) async throws -> [Review]
}
