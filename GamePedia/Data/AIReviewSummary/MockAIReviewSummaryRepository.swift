import Foundation

#if DEBUG
struct MockAIReviewSummaryRepository: AIReviewSummaryRepository {
    func fetchReviewSummary(gameId: Int) async throws -> AIReviewSummary {
        try await Task.sleep(nanoseconds: 500_000_000)

        let response = AIReviewSummaryResponseEnvelopeDTO(
            success: true,
            data: AIReviewSummaryResponseDTO(
                gameId: gameId,
                status: "success",
                reason: "SUMMARY_AVAILABLE",
                fallbackUsed: false,
                summary: "대부분의 리뷰는 느긋한 플레이와 높은 자유도를 장점으로 언급합니다. 농장 관리, 탐험, 관계 쌓기를 자기 속도에 맞춰 즐길 수 있다는 점이 좋은 평가를 받습니다.",
                highlights: [
                    "느긋한 플레이와 높은 자유도",
                    "농장 관리, 탐험, 관계 쌓기의 균형"
                ],
                pros: [
                    "농장 관리와 탐험의 균형이 좋다는 의견이 많습니다.",
                    "힐링 분위기와 도트 그래픽 만족도가 높습니다.",
                    "혼자 오래 플레이해도 목표가 꾸준히 생깁니다.",
                    "캐릭터와 마을 이벤트가 몰입감을 더합니다."
                ],
                cons: [
                    "초반에는 해야 할 일이 많아 다소 복잡하게 느껴질 수 있습니다.",
                    "빠른 전개를 기대하면 반복 작업이 지루할 수 있습니다."
                ],
                recommendedFor: [
                    "느긋한 게임을 선호하는 사용자",
                    "혼자 오래 즐길 수 있는 게임을 찾는 사용자",
                    "수집과 성장 요소를 좋아하는 사용자"
                ],
                notRecommendedFor: [
                    "빠른 전투와 경쟁 중심 플레이를 원하는 사용자",
                    "반복 루틴에 쉽게 지루함을 느끼는 사용자"
                ],
                keywords: ["힐링", "자유도", "농장", "탐험", "수집", "도트 그래픽", "싱글플레이"],
                reviewCount: 24,
                sourceReviewHash: "mock-review-summary-\(gameId)",
                generatedAt: "2026-04-30T00:00:00.000Z",
                disclaimer: nil
            ),
            error: nil
        )

        guard let data = response.data else {
            throw AIReviewSummaryError.invalidResponse
        }

        return AIReviewSummaryMapper.toEntity(data)
    }
}
#endif
