import Foundation

final class DefaultGameRepository: GameRepository {

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchFeaturedGame() async throws -> Game? {
        let dtos = try await apiClient.request(.featuredGame, as: [IGDBGameDTO].self)
        return dtos.first.map(IGDBGameMapper.toEntity)
    }

    func fetchPopularGames(limit: Int) async throws -> [Game] {
        try await fetchGames(endpoint: .popularGames(limit: limit))
    }

    func fetchTrendingGames(limit: Int) async throws -> [Game] {
        try await fetchGames(endpoint: .recommendedGames(limit: limit))
    }

    func fetchLatestGames(limit: Int) async throws -> [Game] {
        try await fetchGames(endpoint: .latestGames(limit: limit))
    }

    func fetchGames(ids: [Int]) async throws -> [Game] {
        guard !ids.isEmpty else { return [] }
        let games = try await fetchGames(endpoint: .games(ids: ids))
        let gamesByID = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
        return ids.compactMap { gamesByID[$0] }
    }

    private func fetchGames(endpoint: Endpoint) async throws -> [Game] {
        let dtos = try await apiClient.request(endpoint, as: [IGDBGameDTO].self)
        return dtos.map(IGDBGameMapper.toEntity)
    }
}
