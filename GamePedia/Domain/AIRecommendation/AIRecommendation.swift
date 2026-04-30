import Foundation

struct AIRecommendationIntentSummary: Equatable {
    let mood: [String]
    let sessionLength: String?
    let playMode: String?
    let difficulty: String?
    let platforms: [String]
    let genres: [String]
    let keywords: [String]
}

struct AIRecommendation: Equatable {
    let gameId: Int
    let title: String
    let coverURL: URL?
    let platforms: [String]
    let genres: [String]
    let rating: Double?
    let reason: String
    let matchTags: [String]
    let rawMatchTags: [String]
    let displayTags: [String]
    let canonicalTags: [String]
    let themes: [String]
    let keywords: [String]
    let reasonTags: [String]
    let intentTags: [String]
    let confidence: Double?
    let recommendationSource: String?
    let personalized: Bool
    let fallbackUsed: Bool

    init(
        gameId: Int,
        title: String,
        coverURL: URL?,
        platforms: [String],
        genres: [String],
        rating: Double?,
        reason: String,
        matchTags: [String],
        rawMatchTags: [String] = [],
        displayTags: [String] = [],
        canonicalTags: [String] = [],
        themes: [String] = [],
        keywords: [String] = [],
        reasonTags: [String] = [],
        intentTags: [String] = [],
        confidence: Double?,
        recommendationSource: String?,
        personalized: Bool,
        fallbackUsed: Bool
    ) {
        self.gameId = gameId
        self.title = title
        self.coverURL = coverURL
        self.platforms = platforms
        self.genres = genres
        self.rating = rating
        self.reason = reason
        self.matchTags = matchTags
        self.rawMatchTags = rawMatchTags
        self.displayTags = displayTags
        self.canonicalTags = canonicalTags
        self.themes = themes
        self.keywords = keywords
        self.reasonTags = reasonTags
        self.intentTags = intentTags
        self.confidence = confidence
        self.recommendationSource = recommendationSource
        self.personalized = personalized
        self.fallbackUsed = fallbackUsed
    }
}

struct AIRecommendationResult: Equatable {
    let requestId: String
    let normalizedQuery: String
    let intent: AIRecommendationIntentSummary?
    let items: [AIRecommendation]
    let meta: AIRecommendationMeta?
    let disclaimer: String?
}

struct AIRecommendationMeta: Equatable {
    let personalizationUsed: Bool?
    let personalizationAvailable: Bool?
    let fallbackUsed: Bool?
    let source: String?
    let candidateCount: Int?
    let generatedAt: String?
}
