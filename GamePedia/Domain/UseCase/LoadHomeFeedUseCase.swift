import Foundation

final class LoadHomeFeedUseCase {

    private let gameRepository: any GameRepository
    private let todayRecommendationsUseCase: GetTodayRecommendationsUseCase
    private let homeHighlightSelector: any HomeHighlightSelecting

    init(
        gameRepository: any GameRepository,
        todayRecommendationsUseCase: GetTodayRecommendationsUseCase,
        homeHighlightSelector: any HomeHighlightSelecting
    ) {
        self.gameRepository = gameRepository
        self.todayRecommendationsUseCase = todayRecommendationsUseCase
        self.homeHighlightSelector = homeHighlightSelector
    }

    func execute() async throws -> HomeFeed {
        async let featuredGame = gameRepository.fetchFeaturedGame()
        async let popularGames = gameRepository.fetchPopularGames(limit: 10)
        async let trendingGames = gameRepository.fetchTrendingGames(limit: 10)
        async let latestGames = gameRepository.fetchLatestGames(limit: 10)

        let featured = try await featuredGame
        let popular = try await popularGames
        let trending = try await trendingGames
        let latest = try await latestGames

        let candidatePool = ([featured].compactMap { $0 } + [popular, trending, latest].flatMap { $0 })
            .uniquedByID()

        let recommendationPool = candidatePool
            .filter { $0.id != featured?.id }

        let highlights = homeHighlightSelector.selectHighlights(
            from: candidatePool,
            minimumCount: 3,
            maximumCount: 5
        )

        let todayRecommendations = await todayRecommendationsUseCase.execute(
            candidates: recommendationPool,
            fallbackPool: recommendationPool,
            limit: 5
        )

        return HomeFeed(
            highlights: highlights,
            todayRecommendations: todayRecommendations.items,
            popularGames: popular,
            trendingGames: trending
        )
    }
}

extension LoadHomeFeedUseCase {
    static func live(
        apiClient: APIClient = .shared,
        userActivityRepository: any UserActivityRepository = LocalUserActivityRepository.shared,
        logger: any RecommendationEventLogger = LocalRecommendationEventLogger.shared,
        engine: any RecommendationServing = RuleBasedRecommendationEngine(),
        homeHighlightSelector: any HomeHighlightSelecting = DefaultHomeHighlightSelector(),
        config: RecommendationConfig = .default
    ) -> LoadHomeFeedUseCase {
        let gameRepository = DefaultGameRepository(apiClient: apiClient)
        let todayRecommendationsUseCase = GetTodayRecommendationsUseCase(
            activityRepository: userActivityRepository,
            recommendationEngine: engine,
            logger: logger,
            config: config
        )
        return LoadHomeFeedUseCase(
            gameRepository: gameRepository,
            todayRecommendationsUseCase: todayRecommendationsUseCase,
            homeHighlightSelector: homeHighlightSelector
        )
    }
}

private extension Array where Element == Game {
    func uniquedByID() -> [Game] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}
