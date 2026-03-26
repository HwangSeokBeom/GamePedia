import Foundation

protocol FavoriteRepository {
    func addFavorite(gameId: String) async throws -> FavoriteMutationResult
    func removeFavorite(gameId: String) async throws -> FavoriteMutationResult
    func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem]
    func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus
}
