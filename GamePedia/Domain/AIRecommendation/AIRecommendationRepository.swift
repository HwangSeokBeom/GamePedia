import Foundation

protocol AIRecommendationRepository {
    func fetchRecommendations(request: AIRecommendationRequest) async throws -> AIRecommendationResult
}

struct AIRecommendationRequest: Equatable {
    let query: String
    let platforms: [String]?
    let preferredGenres: [String]?
    let excludedGameIds: [String]?
    let limit: Int?
    let personalization: Bool
    let includeOwned: Bool?
    let includeReviewed: Bool?
    let includeFavorites: Bool?

    init(
        query: String,
        platforms: [String]? = nil,
        preferredGenres: [String]? = nil,
        excludedGameIds: [String]? = nil,
        limit: Int? = 10,
        personalization: Bool = true,
        includeOwned: Bool? = false,
        includeReviewed: Bool? = false,
        includeFavorites: Bool? = false
    ) {
        self.query = query
        self.platforms = platforms
        self.preferredGenres = preferredGenres
        self.excludedGameIds = excludedGameIds
        self.limit = limit
        self.personalization = personalization
        self.includeOwned = includeOwned
        self.includeReviewed = includeReviewed
        self.includeFavorites = includeFavorites
    }
}
