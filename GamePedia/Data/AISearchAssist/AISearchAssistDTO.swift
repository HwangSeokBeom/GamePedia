import Foundation

struct AISearchAssistRequestDTO: Encodable {
    let query: String
    let platforms: [String]
    let genres: [String]
    let limit: Int
}

struct AISearchAssistResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO?
    let error: AISearchAssistErrorResponseDTO?
}

struct AISearchAssistErrorResponseDTO: Decodable {
    let code: String?
    let message: String?
}

struct AISearchAssistResponseDTO: Decodable {
    let requestId: String
    let originalQuery: String?
    let normalizedQuery: String?
    let intent: AISearchAssistIntentDTO?
    let suggestedQueries: [String]?
    let items: [AISearchAssistItemDTO]
    let fallbackUsed: Bool?
    let disclaimer: String?
}

struct AISearchAssistIntentDTO: Decodable {
    let mood: [String]?
    let sessionLength: String?
    let playMode: String?
    let difficulty: String?
    let platforms: [String]?
    let genres: [String]?
    let keywords: [String]?
}

struct AISearchAssistItemDTO: Decodable {
    let gameId: Int
    let title: String
    let coverUrl: String?
    let platforms: [String]?
    let genres: [String]?
    let rating: Double?
    let matchReason: String?
    let matchTags: [String]?
    let confidence: Double?
}
