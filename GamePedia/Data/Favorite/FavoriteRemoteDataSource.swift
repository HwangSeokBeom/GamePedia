import Foundation

protocol FavoriteRemoteDataSource {
    func addFavorite(requestDTO: AddFavoriteRequestDTO) async throws -> FavoriteMutationResponseDataDTO
    func removeFavorite(gameId: String) async throws -> FavoriteMutationResponseDataDTO
    func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> FavoriteListResponseDataDTO
    func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatusResponseDataDTO
}

final class DefaultFavoriteRemoteDataSource: FavoriteRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func addFavorite(requestDTO: AddFavoriteRequestDTO) async throws -> FavoriteMutationResponseDataDTO {
        let response = try await apiClient.request(
            .addFavorite(body: requestDTO),
            as: FavoriteResponseEnvelopeDTO<FavoriteMutationResponseDataDTO>.self
        )
        return response.data
    }

    func removeFavorite(gameId: String) async throws -> FavoriteMutationResponseDataDTO {
        let response = try await apiClient.request(
            .removeFavorite(gameId: gameId),
            as: FavoriteResponseEnvelopeDTO<FavoriteMutationResponseDataDTO>.self
        )
        return response.data
    }

    func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> FavoriteListResponseDataDTO {
        let response = try await apiClient.request(
            .myFavorites(sort: sort?.rawValue),
            as: FavoriteResponseEnvelopeDTO<FavoriteListResponseDataDTO>.self
        )
        return response.data
    }

    func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatusResponseDataDTO {
        let response = try await apiClient.request(
            .favoriteStatus(gameId: gameId),
            as: FavoriteResponseEnvelopeDTO<FavoriteStatusResponseDataDTO>.self
        )
        return response.data
    }
}
