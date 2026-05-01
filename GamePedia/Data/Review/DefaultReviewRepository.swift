import Foundation

final class DefaultReviewRepository: ReviewRepository {

    private let reviewRemoteDataSource: any ReviewRemoteDataSource
    private static let requestStore = ReviewRequestStore()

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
            await Self.requestStore.invalidateAll()
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
            await Self.requestStore.invalidateAll()
            return ReviewMapper.toEntity(data.review)
        } catch {
            print("[ReviewSubmit] DefaultReviewRepository.updateReview failure error=\(error.localizedDescription)")
            throw ReviewError.from(error: error)
        }
    }

    func deleteReview(reviewId: String) async throws -> ReviewDeletionResult {
        do {
            let data = try await reviewRemoteDataSource.deleteReview(reviewId: reviewId)
            await Self.requestStore.invalidateAll()
            return ReviewMapper.toDeletionResult(data)
        } catch {
            throw ReviewError.from(error: error)
        }
    }

    func fetchMyReviews(sort: ReviewSortOption?) async throws -> [Review] {
        let key = "GET:/users/me/reviews?sort=\(sort?.rawValue ?? "nil")"
        return try await Self.requestStore.value(key: key, ttl: 45) { [reviewRemoteDataSource] in
            do {
                let data = try await reviewRemoteDataSource.fetchMyReviews(sort: sort)
                return data.reviews.map(ReviewMapper.toEntity)
            } catch {
                throw ReviewError.from(error: error)
            }
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

private actor ReviewRequestStore {
    private struct CacheEntry {
        let reviews: [Review]
        let timestamp: Date
    }

    private var inFlightTasks: [String: Task<[Review], Error>] = [:]
    private var cache: [String: CacheEntry] = [:]

    func value(
        key: String,
        ttl: TimeInterval,
        operation: @escaping () async throws -> [Review]
    ) async throws -> [Review] {
        if let cached = cache[key] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < ttl {
#if DEBUG
                print("[RequestCache] hit key=\(key) age=\(Int(age))s")
#endif
                return cached.reviews
            }
        }

        if let task = inFlightTasks[key] {
#if DEBUG
            print("[RequestDedupe] join key=\(key) reason=inFlight")
#endif
            return try await task.value
        }

        let task = Task {
            try await operation()
        }
        inFlightTasks[key] = task

        do {
            let reviews = try await task.value
            cache[key] = CacheEntry(reviews: reviews, timestamp: Date())
            inFlightTasks[key] = nil
            return reviews
        } catch {
            inFlightTasks[key] = nil
            throw error
        }
    }

    func invalidateAll() {
        cache.removeAll()
        inFlightTasks.removeAll()
    }
}
