import Foundation

struct FetchMyReviewsUseCase {
    private let reviewRepository: any ReviewRepository

    init(reviewRepository: any ReviewRepository) {
        self.reviewRepository = reviewRepository
    }

    func execute(sort: ReviewSortOption? = nil) async throws -> [Review] {
        try await reviewRepository.fetchMyReviews(sort: sort)
    }
}
