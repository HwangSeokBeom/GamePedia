import Foundation

enum AIRecommendationMapper {
    static func toEntity(_ dto: AIRecommendationResponseDTO) -> AIRecommendationResult {
        var droppedItemCount = 0
        let items = dto.items.compactMap { dto -> AIRecommendation? in
            guard let item = toItemEntity(dto) else {
                droppedItemCount += 1
                return nil
            }
            return item
        }
#if DEBUG
        print(
            "[AIRecommendationMapping] " +
            "itemCount=\(items.count) " +
            "droppedEmptyGameIdCount=\(droppedItemCount) " +
            "personalizationUsed=\(dto.meta?.personalizationUsed.map(String.init) ?? "nil") " +
            "personalizationAvailable=\(dto.meta?.personalizationAvailable.map(String.init) ?? "nil") " +
            "fallbackUsed=\(dto.meta?.fallbackUsed.map(String.init) ?? "nil") " +
            "source=\(dto.meta?.source ?? "nil")"
        )
#endif
        return AIRecommendationResult(
            requestId: sanitized(dto.requestId) ?? "",
            normalizedQuery: sanitized(dto.normalizedQuery) ?? "",
            intent: dto.intent.map(toIntentEntity),
            items: items,
            meta: dto.meta.map(toMetaEntity),
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
            platforms: dto.platforms ?? [],
            genres: dto.genres ?? [],
            keywords: dto.keywords ?? []
        )
    }

    private static func toMetaEntity(_ dto: AIRecommendationMetaDTO) -> AIRecommendationMeta {
        AIRecommendationMeta(
            personalizationUsed: dto.personalizationUsed,
            personalizationAvailable: dto.personalizationAvailable,
            fallbackUsed: dto.fallbackUsed,
            source: sanitized(dto.source),
            candidateCount: dto.candidateCount,
            generatedAt: sanitized(dto.generatedAt)
        )
    }

    private static func toItemEntity(_ dto: AIRecommendationItemDTO) -> AIRecommendation? {
        guard let gameId = Int(dto.gameId.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return AIRecommendation(
            gameId: gameId,
            title: sanitized(dto.title) ?? L10n.tr("Localizable", "common.label.untitledGame"),
            coverURL: (sanitized(dto.coverUrl) ?? sanitized(dto.imageUrl)).flatMap(URL.init(string:)),
            platforms: sanitized(dto.platforms ?? []),
            genres: sanitized(dto.genres ?? []),
            rating: dto.rating,
            reason: localizedReason(from: dto.reason),
            matchTags: sanitized(dto.matchTags ?? []),
            rawMatchTags: sanitized(dto.rawMatchTags ?? []),
            displayTags: sanitized(dto.displayTags ?? []),
            canonicalTags: sanitized(dto.canonicalTags ?? []),
            themes: sanitized(dto.themes ?? []),
            keywords: sanitized(dto.keywords ?? []),
            reasonTags: sanitized(dto.reasonTags ?? []),
            intentTags: sanitized(dto.intentTags ?? []),
            confidence: dto.confidence,
            recommendationSource: sanitized(dto.recommendationSource),
            personalized: dto.personalized ?? false,
            fallbackUsed: dto.fallbackUsed ?? false
        )
    }

    private static func localizedReason(from reason: String?) -> String {
        guard let reason = sanitized(reason) else {
            return L10n.tr("Localizable", "ai_recommendation_default_reason_query_match")
        }

        return RecommendationTagLocalizer.localizedKnownRecommendationReason(
            for: reason,
            screen: "AIRecommendation"
        ) ?? reason
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func sanitized(_ values: [String]) -> [String] {
        values.compactMap(sanitized)
    }
}
