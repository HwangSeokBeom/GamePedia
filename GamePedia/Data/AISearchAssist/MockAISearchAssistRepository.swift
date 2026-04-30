import Foundation

#if DEBUG
struct MockAISearchAssistRepository: AISearchAssistRepository {
    func fetchSearchAssist(request: AISearchAssistRequest) async throws -> AISearchAssistResult {
        try await Task.sleep(nanoseconds: 400_000_000)

        let response = AISearchAssistResponseDTO(
            requestId: "mock-ai-search-\(UUID().uuidString)",
            originalQuery: request.query,
            normalizedQuery: "짧게 즐길 수 있는 힐링 게임",
            intent: AISearchAssistIntentDTO(
                mood: ["relaxing", "cozy"],
                sessionLength: "short",
                playMode: "singleplayer",
                difficulty: "low",
                platforms: ["PC", "Nintendo Switch"],
                genres: ["Simulation", "Adventure"],
                keywords: ["힐링", "짧은 세션", "농장", "캐주얼"]
            ),
            suggestedQueries: [
                "짧게 즐기는 힐링 게임",
                "퇴근 후 가볍게 할 수 있는 게임"
            ],
            items: [
                AISearchAssistItemDTO(
                    gameId: 1942,
                    title: "Stardew Valley",
                    coverUrl: "https://images.igdb.com/igdb/image/upload/t_cover_big/co49v8.jpg",
                    platforms: ["PC", "Nintendo Switch"],
                    genres: ["Simulator", "Role-playing"],
                    rating: 89.2,
                    matchReason: "짧은 세션으로도 농장 관리와 탐험을 즐길 수 있어요.",
                    matchTags: ["힐링", "짧은 세션", "싱글플레이"],
                    confidence: 0.91
                ),
                AISearchAssistItemDTO(
                    gameId: 1020,
                    title: "Animal Crossing: New Horizons",
                    coverUrl: "https://images.igdb.com/igdb/image/upload/t_cover_big/co22bd.jpg",
                    platforms: ["Nintendo Switch"],
                    genres: ["Simulator", "Adventure"],
                    rating: 86.4,
                    matchReason: "부담 없는 목표와 느긋한 섬 생활이 휴식용 플레이에 잘 맞습니다.",
                    matchTags: ["힐링", "꾸미기", "낮은 난이도"],
                    confidence: 0.86
                )
            ],
            fallbackUsed: false,
            disclaimer: "AI 검색 보조 결과는 참고용이며 실제 검색 결과와 다를 수 있습니다."
        )

        return AISearchAssistMapper.toEntity(response)
    }
}
#endif
