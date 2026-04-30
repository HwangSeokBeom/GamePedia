import Foundation

enum AIReviewSummaryMapper {
    static let defaultDisclaimer = "AI 리뷰 요약은 사용자 리뷰를 기반으로 생성되며, 실제 경험과 다를 수 있습니다."

    static func toEntity(_ dto: AIReviewSummaryResponseDTO) -> AIReviewSummary {
        AIReviewSummary(
            gameId: dto.gameId,
            summary: sanitized(dto.summary) ?? "AI가 리뷰를 요약하고 있습니다.",
            pros: sanitizedArray(dto.pros),
            cons: sanitizedArray(dto.cons),
            recommendedFor: sanitizedArray(dto.recommendedFor),
            notRecommendedFor: sanitizedArray(dto.notRecommendedFor),
            keywords: sanitizedArray(dto.keywords),
            reviewCount: max(0, dto.reviewCount ?? 0),
            sourceReviewHash: sanitized(dto.sourceReviewHash),
            generatedAt: parseDate(dto.generatedAt),
            disclaimer: sanitized(dto.disclaimer) ?? defaultDisclaimer
        )
    }

    private static func sanitizedArray(_ values: [String]?) -> [String] {
        values?.compactMap(sanitized) ?? []
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
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
}
