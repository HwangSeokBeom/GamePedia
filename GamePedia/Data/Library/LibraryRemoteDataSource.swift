import Foundation

protocol LibraryRemoteDataSource {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverviewResponseDataDTO
    func fetchSteamLinkStatus() async throws -> SteamLinkStatusDTO
    func startSteamLink() async throws -> SteamLinkStartResponseDataDTO
    func updateGameStatus(requestDTO: UpdateLibraryStatusRequestDTO) async throws -> LibraryStatusMutationResponseDataDTO
}

final class DefaultLibraryRemoteDataSource: LibraryRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverviewResponseDataDTO {
        let response = try await apiClient.request(
            .myLibrary(sort: sort?.rawValue),
            as: LibraryResponseEnvelopeDTO<LibraryOverviewResponseDataDTO>.self
        )
        return response.data
    }

    func fetchSteamLinkStatus() async throws -> SteamLinkStatusDTO {
        let response = try await apiClient.request(
            .mySteamLinkStatus,
            as: LibraryResponseEnvelopeDTO<SteamLinkStatusDTO>.self
        )
        return response.data
    }

    func startSteamLink() async throws -> SteamLinkStartResponseDataDTO {
        print("[LibrarySteamLink] request endpoint=POST /users/me/library/steam/link")
        let response = try await apiClient.request(
            .startSteamLink,
            as: LibraryResponseEnvelopeDTO<SteamLinkStartResponseDataDTO>.self
        )
        print("[LibrarySteamLink] response authUrl=\(response.data.steamLink.authUrl ?? "nil")")
        return response.data
    }

    func updateGameStatus(requestDTO: UpdateLibraryStatusRequestDTO) async throws -> LibraryStatusMutationResponseDataDTO {
        let response = try await apiClient.request(
            .updateLibraryStatus(body: requestDTO),
            as: LibraryResponseEnvelopeDTO<LibraryStatusMutationResponseDataDTO>.self
        )
        return response.data
    }
}
