import Foundation

final class DefaultFavoriteRepository: FavoriteRepository {
    private let favoriteRemoteDataSource: any FavoriteRemoteDataSource

    init(favoriteRemoteDataSource: any FavoriteRemoteDataSource = DefaultFavoriteRemoteDataSource()) {
        self.favoriteRemoteDataSource = favoriteRemoteDataSource
    }

    func addFavorite(gameId: String) async throws -> FavoriteMutationResult {
        do {
            let data = try await favoriteRemoteDataSource.addFavorite(
                requestDTO: AddFavoriteRequestDTO(gameId: gameId)
            )
            return try FavoriteMapper.toMutationResult(data)
        } catch {
            throw FavoriteError.from(error: error)
        }
    }

    func removeFavorite(gameId: String) async throws -> FavoriteMutationResult {
        do {
            let data = try await favoriteRemoteDataSource.removeFavorite(gameId: gameId)
            return try FavoriteMapper.toMutationResult(data)
        } catch {
            throw FavoriteError.from(error: error)
        }
    }

    func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem] {
        do {
            let data = try await favoriteRemoteDataSource.fetchMyFavorites(sort: sort)
            return try FavoriteMapper.toItems(data.favorites)
        } catch {
            throw FavoriteError.from(error: error)
        }
    }

    func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus {
        do {
            let data = try await favoriteRemoteDataSource.fetchFavoriteStatus(gameId: gameId)
            guard let resolvedGameId = Int(gameId) else {
                throw FavoriteError.invalidGameId
            }
            return FavoriteMapper.toStatusEntity(gameId: resolvedGameId, dto: data)
        } catch {
            throw FavoriteError.from(error: error)
        }
    }
}
