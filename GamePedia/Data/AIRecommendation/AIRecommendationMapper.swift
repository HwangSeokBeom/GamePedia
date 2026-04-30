import Foundation

enum AIRecommendationMapper {
    static func toEntity(_ dto: AIRecommendationResponseDTO) -> AIRecommendationResult {
        AIRecommendationResult(
            requestId: dto.requestId,
            normalizedQuery: sanitized(dto.normalizedQuery) ?? "",
            intent: dto.intent.map(toIntentEntity),
            items: dto.items.map(toItemEntity),
            disclaimer: sanitized(dto.disclaimer)
        )
    }

    static func toGame(_ recommendation: AIRecommendation) -> Game {
        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: recommendation.rating,
            aggregatedRating: nil,
            totalRating: nil
        )

        return Game(
            id: recommendation.gameId,
            title: recommendation.title,
            translatedTitle: nil,
            summary: recommendation.reason,
            translatedSummary: nil,
            genre: recommendation.genres.first ?? L10n.tr("Localizable", "common.label.other"),
            category: recommendation.genres.first ?? L10n.tr("Localizable", "common.label.other"),
            developer: "—",
            platform: recommendation.platforms.first ?? "—",
            releaseDate: nil,
            releaseYear: 0,
            coverImageURL: recommendation.coverURL,
            rating: ratingDisplay.normalizedRating ?? 0,
            reviewCount: 0,
            popularity: recommendation.rating ?? 0,
            isTrending: false,
            formattedRating: ratingDisplay.displayText ?? "—",
            formattedReviewCount: "—"
        )
    }

    private static func toIntentEntity(_ dto: AIRecommendationIntentDTO) -> AIRecommendationIntentSummary {
        AIRecommendationIntentSummary(
            mood: dto.mood ?? [],
            sessionLength: sanitized(dto.sessionLength),
            playMode: sanitized(dto.playMode),
            difficulty: sanitized(dto.difficulty),
            platforms: dto.platforms ?? []
        )
    }

    private static func toItemEntity(_ dto: AIRecommendationItemDTO) -> AIRecommendation {
        AIRecommendation(
            gameId: dto.gameId,
            title: sanitized(dto.title) ?? L10n.tr("Localizable", "common.label.untitledGame"),
            coverURL: sanitized(dto.coverUrl).flatMap(URL.init(string:)),
            platforms: dto.platforms ?? [],
            genres: dto.genres ?? [],
            rating: dto.rating,
            reason: sanitized(dto.reason) ?? "입력한 취향과 잘 맞는 게임입니다.",
            matchTags: dto.matchTags ?? [],
            confidence: dto.confidence
        )
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

