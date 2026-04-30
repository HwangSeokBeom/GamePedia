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
#if DEBUG
        print(
            "[AIRecommendation] remoteRequest " +
            "endpoint=/api/v1/ai/game-recommendations " +
            "queryLength=\(requestDTO.query.count) " +
            "limit=\(requestDTO.limit ?? -1) " +
            "personalization=\(requestDTO.personalization) " +
            "excludedGameIdsCount=\(requestDTO.excludedGameIds?.count ?? 0) " +
            "hasAuthorization=\(apiClient.userAuthToken != nil)"
        )
#endif
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

#if DEBUG
        print(
            "[AIRecommendation] decodeSuccess " +
            "itemCount=\(data.items.count) " +
            "personalizationUsed=\(data.meta?.personalizationUsed.map(String.init) ?? "nil") " +
            "personalizationAvailable=\(data.meta?.personalizationAvailable.map(String.init) ?? "nil") " +
            "fallbackUsed=\(data.meta?.fallbackUsed.map(String.init) ?? "nil") " +
            "source=\(data.meta?.source ?? "nil")"
        )
#endif
        return data
    }
}
