import Foundation

#if DEBUG
struct MockAIRecommendationRepository: AIRecommendationRepository {
    func fetchRecommendations(request: AIRecommendationRequest) async throws -> AIRecommendationResult {
        try await Task.sleep(nanoseconds: 500_000_000)

        return AIRecommendationResult(
            requestId: "mock-ai-rec-\(UUID().uuidString)",
            normalizedQuery: request.query,
            intent: AIRecommendationIntentSummary(
                mood: ["relaxing", "cozy"],
                sessionLength: "short",
                playMode: "singleplayer",
                difficulty: "low",
                platforms: [],
                genres: [],
                keywords: []
            ),
            items: [
                AIRecommendation(
                    gameId: 1942,
                    title: "Stardew Valley",
                    coverURL: URL(string: "https://images.igdb.com/igdb/image/upload/t_cover_big/co49v8.jpg"),
                    platforms: ["PC", "Nintendo Switch"],
                    genres: ["Simulator", "Role-playing"],
                    rating: 89.2,
                    reason: "짧은 플레이 세션으로도 농장 관리와 탐험을 즐길 수 있어요.",
                    matchTags: ["힐링", "짧은 세션", "싱글플레이"],
                    confidence: 0.91,
                    recommendationSource: "mock",
                    personalized: true,
                    fallbackUsed: false
                ),
                AIRecommendation(
                    gameId: 1020,
                    title: "Animal Crossing: New Horizons",
                    coverURL: URL(string: "https://images.igdb.com/igdb/image/upload/t_cover_big/co22bd.jpg"),
                    platforms: ["Nintendo Switch"],
                    genres: ["Simulator", "Adventure"],
                    rating: 86.4,
                    reason: "부담 없는 목표와 느긋한 섬 생활이 휴식용 플레이에 잘 맞습니다.",
                    matchTags: ["힐링", "꾸미기", "낮은 난이도", "긴 태그는 생략"],
                    confidence: 0.86,
                    recommendationSource: "mock",
                    personalized: true,
                    fallbackUsed: false
                )
            ],
            meta: AIRecommendationMeta(
                personalizationUsed: true,
                personalizationAvailable: true,
                fallbackUsed: false,
                source: "mock",
                candidateCount: 2,
                generatedAt: nil
            ),
            disclaimer: "AI 추천은 참고용이며 실제 취향과 다를 수 있습니다."
        )
    }
}
#endif
