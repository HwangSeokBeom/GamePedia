import Foundation

final class DefaultAIRecommendationRepository: AIRecommendationRepository {
    private let remoteDataSource: any AIRecommendationRemoteDataSource

    init(remoteDataSource: any AIRecommendationRemoteDataSource = DefaultAIRecommendationRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchRecommendations(request: AIRecommendationRequest) async throws -> AIRecommendationResult {
        do {
            let requestDTO = AIRecommendationRequestDTO(
                query: request.query,
                platforms: request.platforms,
                preferredGenres: request.preferredGenres,
                excludedGameIds: request.excludedGameIds,
                limit: request.limit,
                personalization: request.personalization,
                includeOwned: request.includeOwned,
                includeReviewed: request.includeReviewed,
                includeFavorites: request.includeFavorites
            )
#if DEBUG
            print(
                "[AIRecommendation] request " +
                "queryLength=\(request.query.count) " +
                "limit=\(request.limit ?? -1) " +
                "personalization=\(request.personalization) " +
                "excludedGameIdsCount=\(request.excludedGameIds?.count ?? 0) " +
                "endpoint=/api/v1/ai/game-recommendations " +
                "hasAuthorization=\(APIClient.shared.userAuthToken != nil)"
            )
#endif
            let responseDTO = try await remoteDataSource.fetchRecommendations(requestDTO: requestDTO)
            return AIRecommendationMapper.toEntity(responseDTO)
        } catch {
            throw AIRecommendationError.from(error: error)
        }
    }
}
