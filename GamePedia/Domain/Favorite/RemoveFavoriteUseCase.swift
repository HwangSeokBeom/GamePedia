import Foundation

struct RemoveFavoriteUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(gameId: String) async throws -> FavoriteMutationResult {
        try await favoriteRepository.removeFavorite(gameId: gameId)
    }
}
