import Foundation

struct FetchMyFavoritesUseCase {
    let favoriteRepository: any FavoriteRepository

    func execute(sort: FavoriteSortOption? = nil) async throws -> [FavoriteItem] {
        try await favoriteRepository.fetchMyFavorites(sort: sort)
    }
}
