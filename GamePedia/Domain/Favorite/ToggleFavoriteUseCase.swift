import Foundation

struct ToggleFavoriteUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(gameId: String, isCurrentlyFavorite: Bool) async throws -> FavoriteMutationResult {
        if isCurrentlyFavorite {
            return try await favoriteRepository.removeFavorite(gameId: gameId)
        }
        return try await favoriteRepository.addFavorite(gameId: gameId)
    }
}
