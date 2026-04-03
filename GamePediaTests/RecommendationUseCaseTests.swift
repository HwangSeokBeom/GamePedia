import XCTest
@testable import GamePedia

final class RecommendationUseCaseTests: XCTestCase {

    func testRuleBasedRecommendationEngine_prioritizesRecentGenreMatchAndSkipsViewedItems() {
        let engine = RuleBasedRecommendationEngine()
        let now = Date(timeIntervalSince1970: 1_710_000_000)

        let rpgCandidate = makeGame(
            id: 1,
            title: "Elden Ring",
            genre: "RPG",
            rating: 4.5,
            popularity: 70,
            releaseDate: daysAgo(160, from: now)
        )
        let sportsCandidate = makeGame(
            id: 2,
            title: "FC Future",
            genre: "Sports",
            rating: 4.8,
            popularity: 88,
            releaseDate: daysAgo(40, from: now)
        )
        let viewedCandidate = makeGame(
            id: 3,
            title: "Persona Revisit",
            genre: "RPG",
            rating: 4.7,
            popularity: 92,
            releaseDate: daysAgo(80, from: now)
        )

        let activity = UserActivity(
            viewedItemIDs: [3],
            likedItemIDs: [],
            recentViewedGenres: ["RPG", "RPG", "Action"],
            recentViewedCategories: ["RPG", "RPG"],
            likedGenres: [],
            likedCategories: [],
            exposedRecommendationIDs: [],
            exposureCountByItemID: [:],
            lastExposedAtByItemID: [:]
        )

        let result = engine.recommend(
            from: [sportsCandidate, viewedCandidate, rpgCandidate],
            activity: activity,
            limit: 3,
            config: .default,
            now: now
        )

        XCTAssertEqual(result.first?.game.id, rpgCandidate.id)
        XCTAssertFalse(result.map(\.game.id).contains(viewedCandidate.id))
        XCTAssertEqual(result.first?.primaryReason.kind, .recentCategoryMatch)
    }

    func testGetTodayRecommendationsUseCase_usesPopularityFallbackWhenSignalsAreMissing() async {
        let activityRepository = InMemoryUserActivityRepository(activity: .empty)
        let logger = SpyRecommendationEventLogger()
        let useCase = GetTodayRecommendationsUseCase(
            activityRepository: activityRepository,
            recommendationEngine: RuleBasedRecommendationEngine(),
            logger: logger,
            config: .default,
            dateProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )

        let popularFirst = makeGame(id: 10, title: "Helldivers", genre: "Action", rating: 4.2, popularity: 95)
        let popularSecond = makeGame(id: 11, title: "Balatro", genre: "Card", rating: 4.7, popularity: 80)

        let result = await useCase.execute(
            candidates: [popularFirst, popularSecond],
            fallbackPool: [popularFirst, popularSecond],
            limit: 2
        )

        XCTAssertEqual(result.source, .fallback(.popular))
        XCTAssertEqual(result.items.map(\.game.id), [10, 11])
        XCTAssertEqual(result.items.first?.primaryReason.kind, .popular)

        let recordedExposureIDs = await activityRepository.recordedExposureIDs()
        XCTAssertEqual(recordedExposureIDs, [10, 11])

        let loggedSources = await logger.loggedSources()
        XCTAssertEqual(loggedSources, [.fallback(.popular)])
    }

    func testLoadHomeFeedUseCase_buildsFeedAndLogsExposureFromSampleData() async throws {
        let featured = makeGame(id: 100, title: "Hades II", genre: "Roguelike", rating: 4.6, popularity: 70)
        let popular = [
            makeGame(id: 1, title: "Elden Ring", genre: "RPG", rating: 4.7, popularity: 93),
            makeGame(id: 2, title: "Metaphor", genre: "RPG", rating: 4.5, popularity: 82)
        ]
        let trending = [
            makeGame(id: 3, title: "Clair Obscur", genre: "RPG", rating: 4.8, popularity: 99, isTrending: true),
            makeGame(id: 4, title: "Tekken 8", genre: "Fighting", rating: 4.2, popularity: 76, isTrending: true)
        ]
        let latest = [
            makeGame(id: 5, title: "Dragon Age", genre: "RPG", rating: 4.1, popularity: 65, releaseDate: Date()),
            makeGame(id: 6, title: "Astro Bot", genre: "Platformer", rating: 4.6, popularity: 84, releaseDate: Date())
        ]

        let gameRepository = StubGameRepository(
            featured: featured,
            popular: popular,
            trending: trending,
            latest: latest
        )
        let activityRepository = InMemoryUserActivityRepository(
            activity: UserActivity(
                viewedItemIDs: [],
                likedItemIDs: [2],
                recentViewedGenres: ["RPG", "RPG", "Action"],
                recentViewedCategories: ["RPG"],
                likedGenres: ["RPG"],
                likedCategories: ["RPG"],
                exposedRecommendationIDs: [],
                exposureCountByItemID: [:],
                lastExposedAtByItemID: [:]
            )
        )
        let logger = SpyRecommendationEventLogger()
        let recommendationUseCase = GetTodayRecommendationsUseCase(
            activityRepository: activityRepository,
            recommendationEngine: RuleBasedRecommendationEngine(),
            logger: logger,
            config: .default,
            dateProvider: Date.init
        )
        let loadHomeFeedUseCase = LoadHomeFeedUseCase(
            gameRepository: gameRepository,
            todayRecommendationsUseCase: recommendationUseCase,
            homeHighlightSelector: DefaultHomeHighlightSelector()
        )

        let feed = try await loadHomeFeedUseCase.execute()

        XCTAssertTrue(feed.highlights.contains(where: { $0.game.id == featured.id }))
        XCTAssertEqual(feed.popularGames.map(\.id), [1, 2])
        XCTAssertEqual(feed.trendingGames.map(\.id), [3, 4])
        XCTAssertFalse(feed.todayRecommendations.isEmpty)
        XCTAssertEqual(feed.todayRecommendations.first?.primaryReason.kind, .recentCategoryMatch)

        let recordedExposureIDs = await activityRepository.recordedExposureIDs()
        XCTAssertEqual(recordedExposureIDs, feed.todayRecommendations.map(\.game.id))

        let loggedSources = await logger.loggedSources()
        XCTAssertEqual(loggedSources.count, 1)
    }

    private func makeGame(
        id: Int,
        title: String,
        genre: String,
        rating: Double,
        popularity: Double,
        summary: String = "전투와 탐험, 성장 구조가 균형 있게 설계된 작품입니다.",
        releaseDate: Date? = Date(timeIntervalSince1970: 1_710_000_000),
        isTrending: Bool = false
    ) -> Game {
        let releaseYear = releaseDate.map { Calendar.current.component(.year, from: $0) } ?? 0
        return Game(
            id: id,
            title: title,
            translatedTitle: nil,
            summary: summary,
            translatedSummary: nil,
            genre: genre,
            category: genre,
            developer: "Studio",
            platform: "PS5",
            releaseDate: releaseDate,
            releaseYear: releaseYear,
            coverImageURL: URL(string: "https://example.com/\(id).jpg"),
            rating: rating,
            reviewCount: Int(popularity),
            popularity: popularity,
            isTrending: isTrending,
            formattedRating: String(format: "%.1f", rating),
            formattedReviewCount: "\(Int(popularity))"
        )
    }

    private func daysAgo(_ days: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
    }
}

private struct StubGameRepository: GameRepository {
    let featured: Game?
    let popular: [Game]
    let trending: [Game]
    let latest: [Game]

    func fetchHighlights(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        _ = filter
        guard let featured else { return [] }
        return Array([featured].prefix(limit))
    }

    func fetchFeaturedGame() async throws -> Game? { featured }
    func fetchPopularGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        _ = filter
        return Array(popular.prefix(limit))
    }
    func fetchTrendingGames(limit: Int, filter: HomeContentFilter?) async throws -> [Game] {
        _ = filter
        return Array(trending.prefix(limit))
    }
    func fetchLatestGames(limit: Int) async throws -> [Game] { Array(latest.prefix(limit)) }
    func fetchGames(ids: [Int]) async throws -> [Game] {
        let pool = [featured].compactMap { $0 } + popular + trending + latest
        let gamesById = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { gamesById[$0] }
    }
}

private actor InMemoryUserActivityRepository: UserActivityRepository {
    private var activity: UserActivity
    private var exposureIDs: [Int] = []

    init(activity: UserActivity) {
        self.activity = activity
    }

    func loadActivity() async -> UserActivity {
        activity
    }

    func recordViewed(game: Game) async {
        activity.viewedItemIDs.insert(game.id, at: 0)
    }

    func recordLiked(game: Game) async {
        activity.likedItemIDs.insert(game.id, at: 0)
    }

    func recordRecommendationExposure(ids: [Int], at: Date) async {
        exposureIDs = ids
        for id in ids {
            activity.exposureCountByItemID[id, default: 0] += 1
            activity.lastExposedAtByItemID[id] = at
        }
    }

    func recordedExposureIDs() async -> [Int] {
        exposureIDs
    }
}

private actor SpyRecommendationEventLogger: RecommendationEventLogger {
    private var sources: [RecommendationSource] = []

    func logImpression(items: [TodayRecommendation], source: RecommendationSource, at: Date) async {
        sources.append(source)
    }

    func loggedSources() async -> [RecommendationSource] {
        sources
    }
}
