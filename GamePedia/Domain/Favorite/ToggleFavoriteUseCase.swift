import Foundation

// The direct favorite mutation path. Since authenticated gestures are owned
// end-to-end by LibrarySyncEngine, this use case only runs for:
//
// - guest gestures (`authorization: .guestOnly`, the default): no
//   authenticated account owned the gesture. The request can never attach a
//   bearer token — even one adopted after the gesture — so it
//   deterministically fails unauthorized (no networking) and drives the
//   existing auth gate.
// - the explicit offline-sync kill-switch (`authorization:
//   .currentSession`): the pre-2.2 legacy behavior, reachable only when
//   `FeatureFlags.enableOfflineLibrarySync` is false.
struct ToggleFavoriteUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(
        gameId: String,
        isCurrentlyFavorite: Bool,
        authorization: RequestAuthorization = .guestOnly
    ) async throws -> FavoriteMutationResult {
        if isCurrentlyFavorite {
            return try await favoriteRepository.removeFavorite(gameId: gameId, authorization: authorization)
        }
        return try await favoriteRepository.addFavorite(gameId: gameId, authorization: authorization)
    }
}
