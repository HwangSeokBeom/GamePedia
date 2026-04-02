import Foundation

protocol GameRepository {
    func fetchHighlights(limit: Int, filter: HomeContentFilter?) async throws -> [Game]
    func fetchFeaturedGame() async throws -> Game?
    func fetchPopularGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game]
    func fetchTrendingGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game]
    func fetchLatestGames(limit: Int) async throws -> [Game]
    func fetchGames(ids: [Int]) async throws -> [Game]
}
