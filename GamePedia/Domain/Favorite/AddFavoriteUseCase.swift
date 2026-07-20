import Foundation

// Direct-path mutation use case; see `ToggleFavoriteUseCase` for the
// guest/kill-switch authorization contract.
struct AddFavoriteUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(
        gameId: String,
        authorization: RequestAuthorization = .guestOnly
    ) async throws -> FavoriteMutationResult {
        try await favoriteRepository.addFavorite(gameId: gameId, authorization: authorization)
    }
}
