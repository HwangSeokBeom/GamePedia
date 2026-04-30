import Foundation

enum AISearchAssistMapper {
    static func toEntity(_ dto: AISearchAssistResponseDTO) -> AISearchAssistResult {
        AISearchAssistResult(
            requestId: dto.requestId,
            originalQuery: sanitized(dto.originalQuery) ?? "",
            normalizedQuery: sanitized(dto.normalizedQuery) ?? "",
            intent: dto.intent.map(toIntentEntity),
            suggestedQueries: sanitized(dto.suggestedQueries ?? []),
            items: dto.items.map(toItemEntity),
            fallbackUsed: dto.fallbackUsed ?? false,
            disclaimer: sanitized(dto.disclaimer)
        )
    }

    static func toGame(_ item: AISearchAssistItem) -> Game {
        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: item.rating,
            aggregatedRating: nil,
            totalRating: nil
        )

        return Game(
            id: item.gameId,
            title: item.title,
            translatedTitle: nil,
            summary: item.matchReason,
            translatedSummary: nil,
            genre: item.genres.first ?? L10n.tr("Localizable", "common.label.other"),
            category: item.genres.first ?? L10n.tr("Localizable", "common.label.other"),
            developer: "—",
            platform: item.platforms.first ?? "—",
            releaseDate: nil,
            releaseYear: 0,
            coverImageURL: item.coverURL,
            rating: ratingDisplay.normalizedRating ?? 0,
            reviewCount: 0,
            popularity: item.rating ?? 0,
            isTrending: false,
            formattedRating: ratingDisplay.displayText ?? "—",
            formattedReviewCount: "—"
        )
    }

    private static func toIntentEntity(_ dto: AISearchAssistIntentDTO) -> AISearchAssistIntentSummary {
        AISearchAssistIntentSummary(
            mood: sanitized(dto.mood ?? []),
            sessionLength: sanitized(dto.sessionLength),
            playMode: sanitized(dto.playMode),
            difficulty: sanitized(dto.difficulty),
            platforms: sanitized(dto.platforms ?? []),
            genres: sanitized(dto.genres ?? []),
            keywords: sanitized(dto.keywords ?? [])
        )
    }

    private static func toItemEntity(_ dto: AISearchAssistItemDTO) -> AISearchAssistItem {
        AISearchAssistItem(
            gameId: dto.gameId,
            title: sanitized(dto.title) ?? L10n.tr("Localizable", "common.label.untitledGame"),
            coverURL: sanitized(dto.coverUrl).flatMap(URL.init(string:)),
            platforms: sanitized(dto.platforms ?? []),
            genres: sanitized(dto.genres ?? []),
            rating: dto.rating,
            matchReason: sanitized(dto.matchReason) ?? "검색 의도와 잘 맞는 게임입니다.",
            matchTags: sanitized(dto.matchTags ?? []),
            confidence: dto.confidence
        )
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        guard containsInternalServerDetails(trimmedValue) == false else { return nil }
        return trimmedValue
    }

    private static func sanitized(_ values: [String]) -> [String] {
        values.compactMap(sanitized)
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
