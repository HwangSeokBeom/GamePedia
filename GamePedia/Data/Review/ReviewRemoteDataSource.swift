import Foundation

protocol ReviewRemoteDataSource {
    func createReview(requestDTO: CreateReviewRequestDTO) async throws -> ReviewObjectResponseDataDTO
    func fetchGameReviews(gameId: String, sort: ReviewSortOption?) async throws -> ReviewListResponseDataDTO
    func updateReview(reviewId: String, requestDTO: UpdateReviewRequestDTO) async throws -> ReviewObjectResponseDataDTO
    func deleteReview(reviewId: String) async throws -> DeleteReviewResponseDataDTO
    func fetchMyReviews(sort: ReviewSortOption?) async throws -> MyReviewsResponseDataDTO
}

final class DefaultReviewRemoteDataSource: ReviewRemoteDataSource {

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func createReview(requestDTO: CreateReviewRequestDTO) async throws -> ReviewObjectResponseDataDTO {
        print("[ReviewSubmit] ReviewRemoteDataSource.createReview start gameId=\(requestDTO.gameId) rating=\(requestDTO.rating) trimmedCount=\(requestDTO.content.trimmingCharacters(in: .whitespacesAndNewlines).count)")
        let response = try await apiClient.request(
            .createReview(body: requestDTO),
            as: ReviewResponseEnvelopeDTO<ReviewObjectResponseDataDTO>.self
        )
        print("[ReviewSubmit] ReviewRemoteDataSource.createReview response reviewId=\(response.data.review.id)")
        return response.data
    }

    func fetchGameReviews(gameId: String, sort: ReviewSortOption?) async throws -> ReviewListResponseDataDTO {
        let response = try await apiClient.request(
            .gameReviews(gameId: gameId, sort: sort?.rawValue),
            as: ReviewResponseEnvelopeDTO<ReviewListResponseDataDTO>.self
        )
        return response.data
    }

    func updateReview(reviewId: String, requestDTO: UpdateReviewRequestDTO) async throws -> ReviewObjectResponseDataDTO {
        print("[ReviewSubmit] ReviewRemoteDataSource.updateReview start reviewId=\(reviewId)")
        let response = try await apiClient.request(
            .updateReview(reviewId: reviewId, body: requestDTO),
            as: ReviewResponseEnvelopeDTO<ReviewObjectResponseDataDTO>.self
        )
        print("[ReviewSubmit] ReviewRemoteDataSource.updateReview response reviewId=\(response.data.review.id)")
        return response.data
    }

    func deleteReview(reviewId: String) async throws -> DeleteReviewResponseDataDTO {
        let response = try await apiClient.request(
            .deleteReview(reviewId: reviewId),
            as: ReviewResponseEnvelopeDTO<DeleteReviewResponseDataDTO>.self
        )
        return response.data
    }

    func fetchMyReviews(sort: ReviewSortOption?) async throws -> MyReviewsResponseDataDTO {
        let response = try await apiClient.request(
            .myReviews(sort: sort?.rawValue),
            as: ReviewResponseEnvelopeDTO<MyReviewsResponseDataDTO>.self
        )
        return response.data
    }
}
