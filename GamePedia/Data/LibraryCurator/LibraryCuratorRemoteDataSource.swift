import Foundation

protocol LibraryCuratorRemoteDataSource {
    func fetchCuratorResult(requestDTO: LibraryCuratorRequestDTO) async throws -> LibraryCuratorResponseDataDTO
}

final class DefaultLibraryCuratorRemoteDataSource: LibraryCuratorRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchCuratorResult(requestDTO: LibraryCuratorRequestDTO) async throws -> LibraryCuratorResponseDataDTO {
#if DEBUG
        print(
            "[LibraryCurator] remoteRequest " +
            "endpoint=/api/v1/ai/library-curator " +
            "mode=\(requestDTO.mode) " +
            "locale=\(requestDTO.locale) " +
            "candidateScope=\(requestDTO.candidateScope) " +
            "limit=\(requestDTO.limit) " +
            "queryExists=\(!(requestDTO.query?.isEmpty ?? true)) " +
            "excludedGameIdsCount=\(requestDTO.excludedGameIds.count) " +
            "hasAuthorization=\(apiClient.userAuthToken != nil)"
        )
#endif
        let response = try await apiClient.request(
            .aiLibraryCurator(body: requestDTO),
            as: LibraryCuratorResponseEnvelopeDTO.self
        )

        guard response.success else {
            throw LibraryCuratorError.from(
                serverCode: response.error?.code,
                message: response.error?.message
            )
        }

        guard let data = response.data else {
            throw LibraryCuratorError.invalidResponse
        }

#if DEBUG
        print(
            "[LibraryCurator] decodeSuccess " +
            "source=\(data.source) " +
            "candidateCount=\(data.meta.candidateCount) " +
            "selectedCount=\(data.meta.selectedCount) " +
            "requestedLimit=\(requestDTO.limit)"
        )
#endif
        return data
    }
}
