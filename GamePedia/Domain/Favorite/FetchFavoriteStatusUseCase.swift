import Foundation

struct FetchFavoriteStatusUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(gameId: String) async throws -> FavoriteStatus {
        try await favoriteRepository.fetchFavoriteStatus(gameId: gameId)
    }
}
