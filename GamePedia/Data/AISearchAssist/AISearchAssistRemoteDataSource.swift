import Foundation

protocol AISearchAssistRemoteDataSource {
    func fetchSearchAssist(requestDTO: AISearchAssistRequestDTO) async throws -> AISearchAssistResponseDTO
}

final class DefaultAISearchAssistRemoteDataSource: AISearchAssistRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchSearchAssist(requestDTO: AISearchAssistRequestDTO) async throws -> AISearchAssistResponseDTO {
        let response = try await apiClient.request(
            .aiSearchAssist(body: requestDTO),
            as: AISearchAssistResponseEnvelopeDTO<AISearchAssistResponseDTO>.self
        )

        guard response.success else {
            throw AISearchAssistError.from(
                serverCode: response.error?.code,
                message: response.error?.message
            )
        }

        guard let data = response.data else {
            throw AISearchAssistError.invalidResponse
        }

        return data
    }
}
