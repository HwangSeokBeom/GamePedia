import Foundation

struct AISearchAssistIntentSummary: Equatable {
    let mood: [String]
    let sessionLength: String?
    let playMode: String?
    let difficulty: String?
    let platforms: [String]
    let genres: [String]
    let keywords: [String]
}

struct AISearchAssistItem: Equatable {
    let gameId: Int
    let title: String
    let coverURL: URL?
    let platforms: [String]
    let genres: [String]
    let rating: Double?
    let matchReason: String
    let matchTags: [String]
    let rawMatchTags: [String]
    let displayTags: [String]
    let canonicalTags: [String]
    let themes: [String]
    let keywords: [String]
    let reasonTags: [String]
    let intentTags: [String]
    let confidence: Double?

    init(
        gameId: Int,
        title: String,
        coverURL: URL?,
        platforms: [String],
        genres: [String],
        rating: Double?,
        matchReason: String,
        matchTags: [String],
        rawMatchTags: [String] = [],
        displayTags: [String] = [],
        canonicalTags: [String] = [],
        themes: [String] = [],
        keywords: [String] = [],
        reasonTags: [String] = [],
        intentTags: [String] = [],
        confidence: Double?
    ) {
        self.gameId = gameId
        self.title = title
        self.coverURL = coverURL
        self.platforms = platforms
        self.genres = genres
        self.rating = rating
        self.matchReason = matchReason
        self.matchTags = matchTags
        self.rawMatchTags = rawMatchTags
        self.displayTags = displayTags
        self.canonicalTags = canonicalTags
        self.themes = themes
        self.keywords = keywords
        self.reasonTags = reasonTags
        self.intentTags = intentTags
        self.confidence = confidence
    }
}

struct AISearchAssistResult: Equatable {
    let requestId: String
    let originalQuery: String
    let normalizedQuery: String
    let intent: AISearchAssistIntentSummary?
    let suggestedQueries: [String]
    let items: [AISearchAssistItem]
    let fallbackUsed: Bool
    let disclaimer: String?
}
