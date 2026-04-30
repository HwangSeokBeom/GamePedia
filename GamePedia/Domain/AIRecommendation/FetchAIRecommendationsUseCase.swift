import Foundation

protocol FetchAIRecommendationsUseCase {
    func execute(query: String) async throws -> AIRecommendationResult
}

struct DefaultFetchAIRecommendationsUseCase: FetchAIRecommendationsUseCase {
    private let repository: any AIRecommendationRepository
    private let limit: Int

    init(
        repository: any AIRecommendationRepository = DefaultAIRecommendationRepository(),
        limit: Int = 10
    ) {
        self.repository = repository
        self.limit = limit
    }

    func execute(query: String) async throws -> AIRecommendationResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = AIRecommendationRequest(
            query: trimmedQuery,
            platforms: nil,
            preferredGenres: nil,
            excludedGameIds: [],
            limit: limit,
            personalization: true,
            includeOwned: false,
            includeReviewed: false,
            includeFavorites: false
        )
        return try await repository.fetchRecommendations(request: request)
    }
}
