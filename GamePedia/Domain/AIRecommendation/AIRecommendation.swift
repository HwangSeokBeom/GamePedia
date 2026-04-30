import Foundation

struct AIRecommendationIntentSummary: Equatable {
    let mood: [String]
    let sessionLength: String?
    let playMode: String?
    let difficulty: String?
    let platforms: [String]
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
    let confidence: Double?
}

struct AIRecommendationResult: Equatable {
    let requestId: String
    let normalizedQuery: String
    let intent: AIRecommendationIntentSummary?
    let items: [AIRecommendation]
    let disclaimer: String?
}

