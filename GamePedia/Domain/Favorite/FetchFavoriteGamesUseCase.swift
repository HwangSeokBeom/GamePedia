import Foundation

struct FetchFavoriteGamesUseCase {
    let fetchMyFavoritesUseCase: FetchMyFavoritesUseCase
    let gameRepository: any GameRepository

    func execute(sort: FavoriteSortOption?, screen: String = "FetchFavoriteGamesUseCase") async throws -> [FavoriteGameEntry] {
        let favoriteItems = try await fetchMyFavoritesUseCase.execute(sort: sort)
        print("[Library] favorites fetched favoriteItemsCount=\(favoriteItems.count) screen=\(screen)")
        guard !favoriteItems.isEmpty else { return [] }

        let orderedGameIDs = favoriteItems.map(\.gameId)
        MappingSafety.logDuplicateKeys(
            orderedGameIDs,
            logPrefix: "[FavoriteMapping]",
            keyName: "gameId",
            countLabel: "favoriteCount",
            screen: screen
        )
        let orderedGames = try await gameRepository.fetchGames(ids: orderedGameIDs)
        let gamesByID = MappingSafety.dictionary(
            pairs: orderedGames.map { ($0.id, $0) },
            logPrefix: "[FavoriteMapping]",
            keyName: "gameId",
            countLabel: "gameCount",
            screen: screen,
            mergePolicy: .keepFirst
        )
        let entries: [FavoriteGameEntry] = favoriteItems.compactMap { favoriteItem in
            guard let game = gamesByID[favoriteItem.gameId] else { return nil }
            return FavoriteGameEntry(favorite: favoriteItem, game: game)
        }
        print(
            "[Library] favorites mapped " +
            "requestedGameCount=\(orderedGameIDs.count) " +
            "fetchedGameCount=\(orderedGames.count) " +
            "entryCount=\(entries.count) " +
            "screen=\(screen)"
        )
        return entries
    }
}
