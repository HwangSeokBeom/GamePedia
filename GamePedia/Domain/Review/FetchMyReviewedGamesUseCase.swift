import Foundation

struct FetchMyReviewedGamesUseCase {
    let fetchMyReviewsUseCase: FetchMyReviewsUseCase
    let gameRepository: any GameRepository

    func execute(sort: ReviewSortOption?) async throws -> [ReviewedGame] {
        let reviews = try await fetchMyReviewsUseCase.execute(sort: sort)
        print("[Library] reviews fetched reviewCount=\(reviews.count)")
        let orderedGameIDs = reviews.compactMap { Int($0.gameId) }
        guard !orderedGameIDs.isEmpty else { return [] }

        let games = try await gameRepository.fetchGames(ids: orderedGameIDs)
        let gamesByID = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
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
            "fetchedGameCount=\(games.count) " +
            "reviewedGameCount=\(reviewedGames.count)"
        )
        return reviewedGames
    }
}
