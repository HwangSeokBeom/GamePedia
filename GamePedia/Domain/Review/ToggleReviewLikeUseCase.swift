import Foundation

struct ToggleReviewLikeUseCase {
    let reviewRepository: any ReviewRepository

    func execute(reviewId: String, isCurrentlyLiked: Bool) async throws -> ReviewLikeMutationResult {
        if isCurrentlyLiked {
            return try await reviewRepository.removeReviewLike(reviewId: reviewId)
        }

        return try await reviewRepository.likeReview(reviewId: reviewId)
    }
}
