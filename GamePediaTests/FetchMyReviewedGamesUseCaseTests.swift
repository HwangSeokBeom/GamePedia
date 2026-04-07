import XCTest
@testable import GamePedia

final class FetchMyReviewedGamesUseCaseTests: XCTestCase {
    func testExecute_preservesMultipleReviewsForSameGameId() async throws {
        let sharedGame = makeGame(id: 376092, title: "Shared Game")
        let reviewRepository = StubReviewRepository(reviews: [
            makeReview(id: "review-1", gameId: "376092", rating: 4.5, content: "first review"),
            makeReview(id: "review-2", gameId: "376092", rating: 3.5, content: "second review")
        ])
        let gameRepository = StubReviewedGameRepository(gamesById: [376092: sharedGame])
        let useCase = FetchMyReviewedGamesUseCase(
            fetchMyReviewsUseCase: FetchMyReviewsUseCase(reviewRepository: reviewRepository),
            gameRepository: gameRepository
        )

        let reviewedGames = try await useCase.execute(sort: .latest, screen: "MyReviewsTest")

        XCTAssertEqual(reviewedGames.count, 2)
        XCTAssertEqual(reviewedGames.map(\.reviewId), ["review-1", "review-2"])
        XCTAssertEqual(reviewedGames.map(\.gameId), [376092, 376092])
        XCTAssertEqual(reviewedGames.map(\.game.displayTitle), ["Shared Game", "Shared Game"])
    }

    func testExecute_skipsReviewWhenGameLookupFails() async throws {
        let reviewRepository = StubReviewRepository(reviews: [
            makeReview(id: "review-1", gameId: "376092", rating: 4.5, content: "first review"),
            makeReview(id: "review-2", gameId: "999999", rating: 2.0, content: "missing game")
        ])
        let gameRepository = StubReviewedGameRepository(gamesById: [376092: makeGame(id: 376092, title: "Known Game")])
        let useCase = FetchMyReviewedGamesUseCase(
            fetchMyReviewsUseCase: FetchMyReviewsUseCase(reviewRepository: reviewRepository),
            gameRepository: gameRepository
        )

        let reviewedGames = try await useCase.execute(sort: .latest, screen: "MyReviewsTest")

        XCTAssertEqual(reviewedGames.count, 1)
        XCTAssertEqual(reviewedGames.first?.reviewId, "review-1")
        XCTAssertEqual(reviewedGames.first?.gameId, 376092)
    }

    private func makeReview(id: String, gameId: String, rating: Double, content: String) -> Review {
        Review(
            id: id,
            gameId: gameId,
            rating: rating,
            content: content,
            createdAt: "2026-04-07T00:00:00Z",
            updatedAt: "2026-04-07T00:00:00Z",
            author: ReviewAuthor(id: "user-1", nickname: "Tester", profileImageUrl: nil),
            isMine: true,
            likeCount: 0,
            commentCount: 0,
            isLikedByCurrentUser: false
        )
    }

    private func makeGame(id: Int, title: String) -> Game {
        Game(
            id: id,
            title: title,
            translatedTitle: nil,
            summary: "summary",
            translatedSummary: nil,
            genre: "RPG",
            category: "Action RPG",
            developer: "Studio",
            platform: "PC",
            releaseDate: nil,
            releaseYear: 2024,
            coverImageURL: nil,
            rating: 4.2,
            reviewCount: 10,
            popularity: 0,
            isTrending: false,
            formattedRating: "4.2",
            formattedReviewCount: "10"
        )
    }
}

private struct StubReviewRepository: ReviewRepository {
    let reviews: [Review]

    func createReview(gameId: String, rating: Double, content: String) async throws -> Review {
        fatalError("Not used in tests")
    }

    func fetchGameReviews(gameId: String, sort: ReviewSortOption?) async throws -> GameReviewFeed {
        fatalError("Not used in tests")
    }

    func updateReview(reviewId: String, rating: Double?, content: String?) async throws -> Review {
        fatalError("Not used in tests")
    }

    func deleteReview(reviewId: String) async throws -> ReviewDeletionResult {
        fatalError("Not used in tests")
    }

    func fetchMyReviews(sort: ReviewSortOption?) async throws -> [Review] {
        reviews
    }

    func likeReview(reviewId: String) async throws -> ReviewLikeMutationResult {
        fatalError("Not used in tests")
    }

    func removeReviewLike(reviewId: String) async throws -> ReviewLikeMutationResult {
        fatalError("Not used in tests")
    }
}

private struct StubReviewedGameRepository: GameRepository {
    let gamesById: [Int: Game]

    func fetchHighlights(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        fatalError("Not used in tests")
    }

    func fetchFeaturedGame() async throws -> Game? {
        fatalError("Not used in tests")
    }

    func fetchPopularGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        fatalError("Not used in tests")
    }

    func fetchTrendingGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        fatalError("Not used in tests")
    }

    func fetchLatestGames(limit: Int) async throws -> [Game] {
        fatalError("Not used in tests")
    }

    func fetchGames(ids: [Int]) async throws -> [Game] {
        ids.compactMap { gamesById[$0] }
    }
}
