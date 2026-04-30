import Foundation

struct AIRecommendationRequestDTO: Encodable {
    let query: String
    let platforms: [String]
    let preferredGenres: [String]
    let excludedGameIds: [Int]
    let limit: Int
}

struct AIRecommendationResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO?
    let error: AIRecommendationErrorResponseDTO?
}

struct AIRecommendationErrorResponseDTO: Decodable {
    let code: String?
    let message: String?
}

struct AIRecommendationResponseDTO: Decodable {
    let requestId: String
    let normalizedQuery: String?
    let intent: AIRecommendationIntentDTO?
    let items: [AIRecommendationItemDTO]
    let disclaimer: String?
}

struct AIRecommendationIntentDTO: Decodable {
    let mood: [String]?
    let sessionLength: String?
    let playMode: String?
    let difficulty: String?
    let platforms: [String]?
}

struct AIRecommendationItemDTO: Decodable {
    let gameId: Int
    let title: String
    let coverUrl: String?
    let platforms: [String]?
    let genres: [String]?
    let rating: Double?
    let reason: String?
    let matchTags: [String]?
    let confidence: Double?
}
