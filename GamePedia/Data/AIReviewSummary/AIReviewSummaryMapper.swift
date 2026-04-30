import Foundation

enum AIReviewSummaryMapper {
    static let defaultDisclaimer = "AI 리뷰 요약은 사용자 리뷰를 기반으로 생성되며, 실제 경험과 다를 수 있습니다."

    static func toEntity(_ dto: AIReviewSummaryResponseDTO, fallbackGameId: Int? = nil) -> AIReviewSummary {
        let reviewCount = max(0, dto.reviewCount ?? 0)
        let status = sanitized(dto.status)?.lowercased() ?? resolvedStatus(dto)
        let reason = sanitized(dto.reason)
        let summary = resolvedSummary(
            dto.summary,
            status: status,
            reason: reason,
            reviewCount: reviewCount
        )

        return AIReviewSummary(
            gameId: resolvedGameId(dto.gameId, fallbackGameId: fallbackGameId),
            status: status,
            reason: reason,
            fallbackUsed: dto.fallbackUsed ?? (status == "fallback"),
            highlights: sanitizedArray(dto.highlights),
            summary: summary,
            pros: sanitizedArray(dto.pros),
            cons: sanitizedArray(dto.cons),
            recommendedFor: sanitizedArray(dto.recommendedFor),
            notRecommendedFor: sanitizedArray(dto.notRecommendedFor),
            keywords: sanitizedArray(dto.keywords),
            reviewCount: reviewCount,
            sourceReviewHash: sanitized(dto.sourceReviewHash),
            generatedAt: parseDate(dto.generatedAt),
            disclaimer: sanitized(dto.disclaimer) ?? defaultDisclaimer
        )
    }

    static func hasDisplayableContent(_ dto: AIReviewSummaryResponseDTO) -> Bool {
        sanitized(dto.summary) != nil
            || sanitizedArray(dto.highlights).isEmpty == false
            || sanitizedArray(dto.pros).isEmpty == false
            || sanitizedArray(dto.cons).isEmpty == false
            || sanitizedArray(dto.recommendedFor).isEmpty == false
            || sanitizedArray(dto.notRecommendedFor).isEmpty == false
            || sanitizedArray(dto.keywords).isEmpty == false
            || sanitized(dto.status) != nil
            || sanitized(dto.reason) != nil
    }

    private static func resolvedStatus(_ dto: AIReviewSummaryResponseDTO) -> String {
        if dto.fallbackUsed == true {
            return "fallback"
        }
        if dto.reviewCount == 0 {
            return "empty"
        }
        if hasDisplayableContent(dto) {
            return "success"
        }
        return "empty"
    }

    private static func resolvedSummary(
        _ summary: String?,
        status: String,
        reason: String?,
        reviewCount: Int
    ) -> String {
        if let summary = sanitized(summary) {
            return summary
        }

        switch (status, reason?.uppercased()) {
        case ("empty", "NO_REVIEWS"):
            return "아직 요약할 리뷰가 없어요."
        case ("empty", "INSUFFICIENT_REVIEWS"):
            return "AI 요약을 만들기에는 리뷰가 조금 부족해요."
        case ("fallback", _):
            return "AI 요약을 일시적으로 생성하지 못했어요. 잠시 후 다시 시도해주세요."
        case ("empty", _):
            return reviewCount == 0
                ? "아직 요약할 리뷰가 없어요."
                : "AI 요약을 만들기에는 리뷰가 조금 부족해요."
        default:
            return "AI 리뷰 요약을 불러오지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    private static func resolvedGameId(_ gameId: Int?, fallbackGameId: Int?) -> Int {
        if let gameId, gameId > 0 {
            return gameId
        }
        if let fallbackGameId, fallbackGameId > 0 {
            return fallbackGameId
        }
        return 0
    }

    private static func sanitizedArray(_ values: [String]?) -> [String] {
        values?.compactMap(sanitized) ?? []
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        guard containsInternalServerDetails(trimmedValue) == false else { return nil }
        return trimmedValue
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value = sanitized(value) else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = .withInternetDateTime
        return formatter.date(from: value)
    }

    private static func containsInternalServerDetails(_ value: String) -> Bool {
        let normalizedValue = value.lowercased()
        let internalMarkers = [
            "route get",
            "/api/",
            "was not found",
            "prisma",
            "prismaclientknownrequesterror",
            "invalid",
            "unhandled",
            "stack",
            "error:",
            "sql"
        ]
        return internalMarkers.contains { normalizedValue.contains($0) }
    }
}
