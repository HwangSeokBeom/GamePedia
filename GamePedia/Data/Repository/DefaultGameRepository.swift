import Foundation

final class DefaultGameRepository: GameRepository {

    private let apiClient: APIClient
    private static let detailStore = GameDetailRequestStore()

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchHighlights(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        try await fetchGames(
            endpoint: .highlightGames(limit: limit, filter: filter),
            logLabel: "highlights",
            isTrending: false
        )
    }

    func fetchFeaturedGame() async throws -> Game? {
        try await fetchHighlights(limit: 1, filter: nil).first
    }

    func fetchPopularGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        try await fetchGames(
            endpoint: .popularGames(limit: limit, filter: filter),
            logLabel: "popular",
            isTrending: false
        )
    }

    func fetchTrendingGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        try await fetchGames(
            endpoint: .recommendedGames(limit: limit, filter: filter),
            logLabel: "recommended",
            isTrending: true
        )
    }

    func fetchLatestGames(limit: Int) async throws -> [Game] {
        try await fetchTrendingGames(limit: limit, filter: nil)
    }

    func fetchGames(ids: [Int]) async throws -> [Game] {
        guard !ids.isEmpty else { return [] }

        let uniqueRequestedIDs = MappingSafety.orderedUniqueElements(
            ids,
            logPrefix: "[GameRepository]",
            keyName: "gameId",
            countLabel: "requestCount",
            screen: "DefaultGameRepository.fetchGames"
        )

        let games = try await withThrowingTaskGroup(of: Game.self) { group in
            for id in uniqueRequestedIDs {
                group.addTask { [apiClient] in
                    try await Self.detailStore.value(gameID: id, ttl: 600, backoff: 60) {
                        let response = try await apiClient.request(
                            .gameDetail(id: id),
                            as: GameResponseEnvelopeDTO<GameDetailResponseDataDTO>.self
                        )
                        return GameMapper.toEntity(response.data.game)
                    }
                }
            }

            var collectedGames: [Game] = []
            for try await game in group {
                collectedGames.append(game)
            }
            return collectedGames
        }

        let gamesByID = MappingSafety.dictionary(
            pairs: games.map { ($0.id, $0) },
            logPrefix: "[GameRepository]",
            keyName: "gameId",
            countLabel: "gameCount",
            screen: "DefaultGameRepository.fetchGames",
            mergePolicy: .keepFirst
        )
        let orderedGames = uniqueRequestedIDs.compactMap { gamesByID[$0] }
        print(
            "[GameRepository] details count=\(orderedGames.count) " +
            "requestedCount=\(ids.count) " +
            "uniqueRequestedCount=\(uniqueRequestedIDs.count)"
        )
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

private actor GameDetailRequestStore {
    private struct CacheEntry {
        let game: Game
        let timestamp: Date
    }

    private var inFlightTasks: [Int: Task<Game, Error>] = [:]
    private var cache: [Int: CacheEntry] = [:]
    private var backoffUntil: [Int: Date] = [:]

    func value(
        gameID: Int,
        ttl: TimeInterval,
        backoff: TimeInterval,
        operation: @escaping () async throws -> Game
    ) async throws -> Game {
        let now = Date()
        if let until = backoffUntil[gameID], until > now {
            let remaining = Int(ceil(until.timeIntervalSince(now)))
            if let cached = cache[gameID] {
#if DEBUG
                print("[RateLimitBackoff] suppress key=gameDetail:\(gameID) remaining=\(remaining)s status=429")
                print("[RequestCache] hit key=gameDetail:\(gameID) age=\(Int(now.timeIntervalSince(cached.timestamp)))s")
#endif
                return cached.game
            }
#if DEBUG
            print("[RateLimitBackoff] suppress key=gameDetail:\(gameID) remaining=\(remaining)s status=429")
#endif
            throw NetworkError.rateLimited(statusCode: 429, code: nil, message: "IGDB is temporarily rate limited")
        }

        if let cached = cache[gameID] {
            let age = now.timeIntervalSince(cached.timestamp)
            if age < ttl {
#if DEBUG
                print("[RequestCache] hit key=gameDetail:\(gameID) age=\(Int(age))s")
#endif
                return cached.game
            }
        }

        if let task = inFlightTasks[gameID] {
#if DEBUG
            print("[RequestDedupe] join key=gameDetail:\(gameID) reason=inFlight")
#endif
            return try await task.value
        }

        let task = Task {
            try await operation()
        }
        inFlightTasks[gameID] = task

        do {
            let game = try await task.value
            cache[gameID] = CacheEntry(game: game, timestamp: Date())
            backoffUntil[gameID] = nil
            inFlightTasks[gameID] = nil
            return game
        } catch {
            inFlightTasks[gameID] = nil
            if Self.isRateLimit(error) {
                backoffUntil[gameID] = Date().addingTimeInterval(backoff)
                if let cached = cache[gameID] {
#if DEBUG
                    print("[RateLimitBackoff] cacheFallback key=gameDetail:\(gameID) status=429")
#endif
                    return cached.game
                }
            }
            throw error
        }
    }

    private static func isRateLimit(_ error: Error) -> Bool {
        if case NetworkError.rateLimited = error {
            return true
        }
        return false
    }
}
