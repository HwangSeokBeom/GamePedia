import Foundation

protocol LibraryRemoteDataSource {
    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverviewResponseDataDTO
    func fetchSteamLinkStatus() async throws -> SteamLinkStatusDTO
    func startSteamLink() async throws -> SteamLinkStartResponseDataDTO
    func syncOwnedSteamLibrary() async throws -> SyncOwnedSteamLibraryResponseDataDTO
    func updateGameStatus(requestDTO: UpdateLibraryStatusRequestDTO) async throws -> LibraryStatusMutationResponseDataDTO
}

final class DefaultLibraryRemoteDataSource: LibraryRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchLibraryOverview(sort: UserGameCollectionSortOption?) async throws -> LibraryOverviewResponseDataDTO {
        print("[Library] request endpoint=GET /users/me/library sort=\(sort?.rawValue ?? "nil")")
        let response = try await apiClient.request(
            .myLibrary(sort: sort?.rawValue),
            as: LibraryResponseEnvelopeDTO<LibraryOverviewResponseDataDTO>.self
        )
        let data = response.data
        let likedCount = data.liked?.count ?? data.wishlist?.count ?? 0
        let reviewsCount = data.reviews?.count ?? data.reviewed?.count ?? 0
        print(
            "[Library] response endpoint=GET /users/me/library " +
            "steamConnected=\(data.steamConnected.map(String.init) ?? "nil") " +
            "steamSyncAvailable=\(data.steamSyncAvailable.map(String.init) ?? "nil") " +
            "recentlyPlayedCount=\(data.recentlyPlayed?.count ?? 0) " +
            "playingCount=\(data.playing?.count ?? 0) " +
            "likedCount=\(likedCount) " +
            "reviewsCount=\(reviewsCount)"
        )
        return data
    }

    func fetchSteamLinkStatus() async throws -> SteamLinkStatusDTO {
        let response = try await apiClient.request(
            .mySteamLinkStatus,
            as: LibraryResponseEnvelopeDTO<SteamLinkStatusDTO>.self
        )
        return response.data
    }

    func startSteamLink() async throws -> SteamLinkStartResponseDataDTO {
        print("[SteamLink] request endpoint=POST /users/me/library/steam/link")
        let response = try await apiClient.request(
            .startSteamLink,
            as: LibraryResponseEnvelopeDTO<SteamLinkStartResponseDataDTO>.self
        )
        print("[SteamLink] response authUrl=\(response.data.steamLink.authUrl ?? "nil")")
        return response.data
    }

    func syncOwnedSteamLibrary() async throws -> SyncOwnedSteamLibraryResponseDataDTO {
        print("[Library] request endpoint=POST /users/me/library/steam/sync-owned")
        let response = try await apiClient.request(
            .syncOwnedSteamLibrary,
            as: LibraryResponseEnvelopeDTO<SyncOwnedSteamLibraryResponseDataDTO>.self
        )
        print(
            "[Library] response endpoint=POST /users/me/library/steam/sync-owned " +
            "syncedCount=\(response.data.syncedCount) " +
            "insertedCount=\(response.data.insertedCount) " +
            "updatedCount=\(response.data.updatedCount) " +
            "syncWarningCode=\(response.data.syncWarningCode ?? "nil") " +
            "igdbEnrichmentApplied=\(response.data.igdbEnrichmentApplied.map(String.init) ?? "nil") " +
            "igdbEnrichmentSkippedReason=\(response.data.igdbEnrichmentSkippedReason ?? "nil")"
        )
        return response.data
    }

    func updateGameStatus(requestDTO: UpdateLibraryStatusRequestDTO) async throws -> LibraryStatusMutationResponseDataDTO {
        print(
            "[Library] request endpoint=POST /users/me/library/status " +
            "externalGameId=\(requestDTO.externalGameId) " +
            "title=\(requestDTO.title) " +
            "gameSource=\(requestDTO.gameSource.uppercased()) " +
            "status=\(requestDTO.status)"
        )
        let response = try await apiClient.request(
            .updateLibraryStatus(body: requestDTO),
            as: LibraryResponseEnvelopeDTO<LibraryStatusMutationResponseEnvelopeDataDTO>.self
        )
        print(
            "[Library] response endpoint=POST /users/me/library/status " +
            "externalGameId=\(response.data.libraryEntry.externalGameId ?? "nil") " +
            "status=\(response.data.libraryEntry.status)"
        )
        return response.data.libraryEntry
    }
}
