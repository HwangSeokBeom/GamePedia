import Foundation

final class DefaultGameRepository: GameRepository {

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchHighlights(limit: Int) async throws -> [Game] {
        try await fetchGames(
            endpoint: .highlightGames(limit: limit),
            logLabel: "highlights",
            isTrending: false
        )
    }

    func fetchFeaturedGame() async throws -> Game? {
        try await fetchHighlights(limit: 1).first
    }

    func fetchPopularGames(limit: Int) async throws -> [Game] {
        try await fetchGames(
            endpoint: .popularGames(limit: limit),
            logLabel: "popular",
            isTrending: false
        )
    }

    func fetchTrendingGames(limit: Int) async throws -> [Game] {
        try await fetchGames(
            endpoint: .recommendedGames(limit: limit),
            logLabel: "recommended",
            isTrending: true
        )
    }

    func fetchLatestGames(limit: Int) async throws -> [Game] {
        try await fetchTrendingGames(limit: limit)
    }

    func fetchGames(ids: [Int]) async throws -> [Game] {
        guard !ids.isEmpty else { return [] }

        let games = try await withThrowingTaskGroup(of: Game.self) { group in
            for id in ids {
                group.addTask { [apiClient] in
                    let response = try await apiClient.request(
                        .gameDetail(id: id),
                        as: GameResponseEnvelopeDTO<GameDetailResponseDataDTO>.self
                    )
                    return GameMapper.toEntity(response.data.game)
                }
            }

            var collectedGames: [Game] = []
            for try await game in group {
                collectedGames.append(game)
            }
            return collectedGames
        }

        let gamesByID = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
        let orderedGames = ids.compactMap { gamesByID[$0] }
        print("[GameRepository] details count=\(orderedGames.count)")
        return orderedGames
    }

    private func fetchGames(
        endpoint: Endpoint,
        logLabel: String,
        isTrending: Bool
    ) async throws -> [Game] {
        let response = try await apiClient.request(
            endpoint,
            as: GameResponseEnvelopeDTO<GameListResponseDataDTO>.self
        )
        let games = response.data.games.map { GameMapper.toEntity($0, isTrending: isTrending) }
        print("[GameRepository] \(logLabel) count=\(games.count)")
        return games
    }
}
