import Foundation

protocol AIReviewSummaryRemoteDataSource {
    func fetchReviewSummary(gameId: Int) async throws -> AIReviewSummaryResponseDTO
}

final class DefaultAIReviewSummaryRemoteDataSource: AIReviewSummaryRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchReviewSummary(gameId: Int) async throws -> AIReviewSummaryResponseDTO {
        let response = try await apiClient.request(
            .aiReviewSummary(gameId: gameId),
            as: AIReviewSummaryResponseEnvelopeDTO<AIReviewSummaryResponseDTO>.self
        )

        guard response.success else {
            if let data = response.data,
               AIReviewSummaryMapper.hasDisplayableContent(data) {
                return data
            }

            throw AIReviewSummaryError.from(
                serverCode: response.error?.code,
                message: response.error?.message
            )
        }

        guard let data = response.data else {
            throw AIReviewSummaryError.invalidResponse
        }

        return data
    }
}
