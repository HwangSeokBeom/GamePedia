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

    func execute(filter: HomeContentFilter = .default) async throws -> HomeFeed {
        async let highlightGames = gameRepository.fetchHighlights(limit: 5, filter: filter)
        async let popularGames = gameRepository.fetchPopularGames(limit: 10, filter: filter)
        async let trendingGames = gameRepository.fetchTrendingGames(limit: 10, filter: filter)

        let highlightsSource = try await highlightGames
        let popular = try await popularGames
        let trending = try await trendingGames

        let candidatePool = (highlightsSource + [popular, trending].flatMap { $0 })
            .uniquedByID()

        let highlightIDs = Set(highlightsSource.map(\.id))
        let recommendationPool = candidatePool
            .filter { !highlightIDs.contains($0.id) }

        let highlights = homeHighlightSelector.selectHighlights(
            from: highlightsSource,
            minimumCount: 3,
            maximumCount: 5
        )

        let todayRecommendations = await todayRecommendationsUseCase.execute(
            candidates: recommendationPool.isEmpty ? candidatePool : recommendationPool,
            fallbackPool: candidatePool,
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
