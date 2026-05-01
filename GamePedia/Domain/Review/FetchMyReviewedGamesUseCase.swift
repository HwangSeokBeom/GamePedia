import Foundation

struct FetchMyReviewedGamesUseCase {
    let fetchMyReviewsUseCase: FetchMyReviewsUseCase
    let gameRepository: any GameRepository

    func execute(sort: ReviewSortOption?, screen: String = "FetchMyReviewedGamesUseCase") async throws -> [ReviewedGame] {
        let reviews = try await fetchMyReviewsUseCase.execute(sort: sort)
        print("[Library] reviews fetched reviewCount=\(reviews.count) screen=\(screen)")
        let orderedGameIDs = reviews.compactMap { Int($0.gameId) }
        MappingSafety.logDuplicateKeys(
            orderedGameIDs,
            logPrefix: "[ReviewMapping]",
            keyName: "gameId",
            countLabel: "reviewCount",
            screen: screen
        )
        guard !orderedGameIDs.isEmpty else { return [] }
        let uniqueGameIDs = MappingSafety.orderedUniqueElements(
            orderedGameIDs,
            logPrefix: "[ReviewMapping]",
            keyName: "gameId",
            countLabel: "detailRequestCount",
            screen: "\(screen).detailFetch"
        )

        let games = try await gameRepository.fetchGames(ids: uniqueGameIDs)
        let gamesByID = MappingSafety.dictionary(
            pairs: games.map { ($0.id, $0) },
            logPrefix: "[ReviewMapping]",
            keyName: "gameId",
            countLabel: "gameCount",
            screen: screen,
            mergePolicy: .keepFirst
        )
        let reviewedGames: [ReviewedGame] = reviews.compactMap { review in
            guard let gameId = Int(review.gameId),
                  let game = gamesByID[gameId] else {
                return nil
            }

            return ReviewedGame(
                reviewId: review.id,
                gameId: gameId,
                rating: review.rating,
                content: review.content,
                createdAt: review.createdAt,
                game: game
            )
        }
        print(
            "[Library] reviews mapped " +
            "requestedGameCount=\(orderedGameIDs.count) " +
            "uniqueRequestedGameCount=\(uniqueGameIDs.count) " +
            "fetchedGameCount=\(games.count) " +
            "reviewedGameCount=\(reviewedGames.count) " +
            "screen=\(screen)"
        )
        return reviewedGames
    }
}
