import Foundation

protocol GameRepository {
    func fetchFeaturedGame() async throws -> Game?
    func fetchPopularGames(limit: Int) async throws -> [Game]
    func fetchTrendingGames(limit: Int) async throws -> [Game]
    func fetchLatestGames(limit: Int) async throws -> [Game]
    func fetchGames(ids: [Int]) async throws -> [Game]
}
