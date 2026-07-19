import Foundation

protocol FavoriteRepository {
    /// Mutations carry an explicit authorization mode so account ownership
    /// and credential selection bind atomically at the network boundary:
    /// engine-owned replays pass `.boundAccount`, guest gestures pass
    /// `.guestOnly` (which can never attach a bearer token), and only the
    /// explicit kill-switch legacy path passes `.currentSession`.
    func addFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult
    func removeFavorite(gameId: String, authorization: RequestAuthorization) async throws -> FavoriteMutationResult
    func fetchMyFavorites(sort: FavoriteSortOption?) async throws -> [FavoriteItem]
    func fetchFavoriteStatus(gameId: String) async throws -> FavoriteStatus
}
