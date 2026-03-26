import Foundation

struct AddFavoriteUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(gameId: String) async throws -> FavoriteMutationResult {
        try await favoriteRepository.addFavorite(gameId: gameId)
    }
}
