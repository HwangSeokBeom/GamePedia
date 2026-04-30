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
    let confidence: Double?
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
