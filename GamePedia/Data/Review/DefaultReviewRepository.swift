import Foundation

final class DefaultReviewRepository: ReviewRepository {

    private let reviewRemoteDataSource: any ReviewRemoteDataSource

    init(reviewRemoteDataSource: any ReviewRemoteDataSource = DefaultReviewRemoteDataSource()) {
        self.reviewRemoteDataSource = reviewRemoteDataSource
    }

    func createReview(gameId: String, rating: Double, content: String) async throws -> Review {
        do {
            print("[ReviewSubmit] DefaultReviewRepository.createReview gameId=\(gameId) rating=\(rating)")
            let data = try await reviewRemoteDataSource.createReview(
                requestDTO: CreateReviewRequestDTO(
                    gameId: gameId,
                    rating: rating,
                    content: content
                )
            )
            print("[ReviewSubmit] DefaultReviewRepository.createReview success reviewId=\(data.review.id)")
            return ReviewMapper.toEntity(data.review)
        } catch {
            print("[ReviewSubmit] DefaultReviewRepository.createReview failure error=\(error.localizedDescription)")
            throw ReviewError.from(error: error)
        }
    }

    func fetchGameReviews(gameId: String, sort: ReviewSortOption?) async throws -> GameReviewFeed {
        do {
            let data = try await reviewRemoteDataSource.fetchGameReviews(gameId: gameId, sort: sort)
            return ReviewMapper.toFeedEntity(data)
        } catch {
            throw ReviewError.from(error: error)
        }
    }

    func updateReview(reviewId: String, rating: Double?, content: String?) async throws -> Review {
        do {
            print("[ReviewSubmit] DefaultReviewRepository.updateReview reviewId=\(reviewId)")
            let data = try await reviewRemoteDataSource.updateReview(
                reviewId: reviewId,
                requestDTO: UpdateReviewRequestDTO(
                    rating: rating,
                    content: content
                )
            )
            print("[ReviewSubmit] DefaultReviewRepository.updateReview success reviewId=\(data.review.id)")
            return ReviewMapper.toEntity(data.review)
        } catch {
            print("[ReviewSubmit] DefaultReviewRepository.updateReview failure error=\(error.localizedDescription)")
            throw ReviewError.from(error: error)
        }
    }

    func deleteReview(reviewId: String) async throws -> ReviewDeletionResult {
        do {
            let data = try await reviewRemoteDataSource.deleteReview(reviewId: reviewId)
            return ReviewMapper.toDeletionResult(data)
        } catch {
            throw ReviewError.from(error: error)
        }
    }

    func fetchMyReviews(sort: ReviewSortOption?) async throws -> [Review] {
        do {
            let data = try await reviewRemoteDataSource.fetchMyReviews(sort: sort)
            return data.reviews.map(ReviewMapper.toEntity)
        } catch {
            throw ReviewError.from(error: error)
        }
    }

    func likeReview(reviewId: String) async throws -> ReviewLikeMutationResult {
        do {
            let data = try await reviewRemoteDataSource.likeReview(reviewId: reviewId)
            return ReviewMapper.toLikeMutationResult(data)
        } catch {
            throw ReviewError.from(error: error)
        }
    }

    func removeReviewLike(reviewId: String) async throws -> ReviewLikeMutationResult {
        do {
            let data = try await reviewRemoteDataSource.removeReviewLike(reviewId: reviewId)
            return ReviewMapper.toLikeMutationResult(data)
        } catch {
            throw ReviewError.from(error: error)
        }
    }
}
