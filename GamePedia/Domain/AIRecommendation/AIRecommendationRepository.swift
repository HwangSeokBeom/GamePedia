import Foundation

protocol AIRecommendationRepository {
    func fetchRecommendations(request: AIRecommendationRequest) async throws -> AIRecommendationResult
}

struct AIRecommendationRequest: Equatable {
    let query: String
    let platforms: [String]
    let preferredGenres: [String]
    let excludedGameIds: [Int]
    let limit: Int
}

