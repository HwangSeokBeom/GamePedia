import Foundation

// Direct-path mutation use case; see `ToggleFavoriteUseCase` for the
// guest/kill-switch authorization contract.
struct RemoveFavoriteUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(
        gameId: String,
        authorization: RequestAuthorization = .guestOnly
    ) async throws -> FavoriteMutationResult {
        try await favoriteRepository.removeFavorite(gameId: gameId, authorization: authorization)
    }
}
