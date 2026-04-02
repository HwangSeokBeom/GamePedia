import Foundation

struct FetchFavoriteGamesUseCase {
    let fetchMyFavoritesUseCase: FetchMyFavoritesUseCase
    let gameRepository: any GameRepository

    func execute(sort: FavoriteSortOption?) async throws -> [FavoriteGameEntry] {
        let favoriteItems = try await fetchMyFavoritesUseCase.execute(sort: sort)
        print("[Library] favorites fetched favoriteItemsCount=\(favoriteItems.count)")
        guard !favoriteItems.isEmpty else { return [] }

        let orderedGameIDs = favoriteItems.map(\.gameId)
        let orderedGames = try await gameRepository.fetchGames(ids: orderedGameIDs)
        let gamesByID = Dictionary(uniqueKeysWithValues: orderedGames.map { ($0.id, $0) })
        let entries: [FavoriteGameEntry] = favoriteItems.compactMap { favoriteItem in
            guard let game = gamesByID[favoriteItem.gameId] else { return nil }
            return FavoriteGameEntry(favorite: favoriteItem, game: game)
        }
        print(
            "[Library] favorites mapped " +
            "requestedGameCount=\(orderedGameIDs.count) " +
            "fetchedGameCount=\(orderedGames.count) " +
            "entryCount=\(entries.count)"
        )
        return entries
    }
}
