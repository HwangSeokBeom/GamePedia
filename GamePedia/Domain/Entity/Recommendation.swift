import Foundation

// MARK: - HomeFeed

struct HomeFeed {
    let highlights: [HomeHighlightItem]
    let todayRecommendations: [TodayRecommendation]
    let popularGames: [Game]
    let trendingGames: [Game]
}

// MARK: - HomeHighlightItem

struct HomeHighlightItem: Hashable {
    let game: Game
    let badgeText: String
    let titleText: String
    let metaText: String
    let supportingText: String
}

// MARK: - UserActivity

struct UserActivity: Equatable {
    var viewedItemIDs: [Int]
    var likedItemIDs: [Int]
    var recentViewedGenres: [String]
    var recentViewedCategories: [String]
    var likedGenres: [String]
    var likedCategories: [String]
    var exposedRecommendationIDs: [Int]
    var exposureCountByItemID: [Int: Int]
    var lastExposedAtByItemID: [Int: Date]

    static let empty = UserActivity(
        viewedItemIDs: [],
        likedItemIDs: [],
        recentViewedGenres: [],
        recentViewedCategories: [],
        likedGenres: [],
        likedCategories: [],
        exposedRecommendationIDs: [],
        exposureCountByItemID: [:],
        lastExposedAtByItemID: [:]
    )

    var hasPersonalizationSignals: Bool {
        !recentViewedGenres.isEmpty ||
        !recentViewedCategories.isEmpty ||
        !likedGenres.isEmpty ||
        !likedCategories.isEmpty ||
        !likedItemIDs.isEmpty
    }

    func exposureCount(for itemID: Int) -> Int {
        exposureCountByItemID[itemID, default: 0]
    }

    func lastExposedAt(for itemID: Int) -> Date? {
        lastExposedAtByItemID[itemID]
    }
}

// MARK: - RecommendationSource

enum RecommendationFallbackStrategy: String, Hashable {
    case popular
    case latest
    case editorPick
}

enum RecommendationSource: Hashable {
    case personalized
    case fallback(RecommendationFallbackStrategy)

    var storageValue: String {
        switch self {
        case .personalized:
            return "personalized"
        case .fallback(let strategy):
            return "fallback:\(strategy.rawValue)"
        }
    }
}

// MARK: - RecommendationReason

enum RecommendationReasonKind: String, Hashable, Codable {
    case recentCategoryMatch
    case likedSimilarity
    case highRating
    case popular
    case freshness
    case editorPick
}

struct RecommendationReason: Hashable, Codable {
    let kind: RecommendationReasonKind
    let message: String
    let weight: Double
}

// MARK: - RecommendationScoreBreakdown

struct RecommendationScoreBreakdown: Hashable {
    let recentCategoryMatchScore: Double
    let likedSimilarityScore: Double
    let highRatingScore: Double
    let popularityScore: Double
    let freshnessScore: Double
    let exposurePenalty: Double
    let watchedPenalty: Double

    var finalScore: Double {
        recentCategoryMatchScore +
        likedSimilarityScore +
        highRatingScore +
        popularityScore +
        freshnessScore -
        exposurePenalty -
        watchedPenalty
    }
}

// MARK: - TodayRecommendation

struct TodayRecommendation: Hashable {
    let game: Game
    let score: Double
    let primaryReason: RecommendationReason
    let reasons: [RecommendationReason]
    let scoreBreakdown: RecommendationScoreBreakdown
    let source: RecommendationSource
}

struct RecommendationResult: Hashable {
    let items: [TodayRecommendation]
    let source: RecommendationSource
}

// MARK: - RecommendationConfig

struct RecommendationConfig: Hashable {
    let recentCategoryMatchWeight: Double
    let likedSimilarityWeight: Double
    let highRatingWeight: Double
    let popularityWeight: Double
    let freshnessWeight: Double
    let exposurePenaltyWeight: Double
    let watchedPenaltyWeight: Double
    let reasonThreshold: Double
    let excludeViewedItems: Bool

    static let `default` = RecommendationConfig(
        recentCategoryMatchWeight: 28,
        likedSimilarityWeight: 24,
        highRatingWeight: 18,
        popularityWeight: 14,
        freshnessWeight: 10,
        exposurePenaltyWeight: 12,
        watchedPenaltyWeight: 60,
        reasonThreshold: 6,
        excludeViewedItems: true
    )
}
