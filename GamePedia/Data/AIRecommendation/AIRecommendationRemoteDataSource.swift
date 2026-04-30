import Foundation

protocol AIRecommendationRemoteDataSource {
    func fetchRecommendations(requestDTO: AIRecommendationRequestDTO) async throws -> AIRecommendationResponseDTO
}

final class DefaultAIRecommendationRemoteDataSource: AIRecommendationRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchRecommendations(requestDTO: AIRecommendationRequestDTO) async throws -> AIRecommendationResponseDTO {
        let response = try await apiClient.request(
            .aiGameRecommendations(body: requestDTO),
            as: AIRecommendationResponseEnvelopeDTO<AIRecommendationResponseDTO>.self
        )

        guard response.success else {
            throw AIRecommendationError.from(
                serverCode: response.error?.code,
                message: response.error?.message
            )
        }

        guard let data = response.data else {
            throw AIRecommendationError.invalidResponse
        }

        return data
    }
}
