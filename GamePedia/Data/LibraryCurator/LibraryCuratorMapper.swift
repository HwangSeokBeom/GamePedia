import Foundation

enum LibraryCuratorMapper {
    static func toEntity(_ dto: LibraryCuratorResponseDataDTO) -> LibraryCuratorResult {
        let mode = LibraryCuratorMode(rawValue: sanitized(dto.mode) ?? "") ?? .overview
        return LibraryCuratorResult(
            mode: mode,
            source: sanitized(dto.source) ?? "fallback",
            summary: LibraryCuratorSummary(
                title: sanitized(dto.summary.title) ?? "",
                body: sanitized(dto.summary.body) ?? "",
                bullets: sanitized(dto.summary.bullets)
            ),
            tasteProfile: LibraryCuratorTasteProfile(
                topGenres: sanitized(dto.tasteProfile.topGenres),
                topThemes: sanitized(dto.tasteProfile.topThemes),
                preferredSession: sanitized(dto.tasteProfile.preferredSession) ?? "",
                playStyleTags: sanitized(dto.tasteProfile.playStyleTags),
                ratingStyle: sanitized(dto.tasteProfile.ratingStyle)
            ),
            sections: dto.sections.map { section in
                LibraryCuratorSection(
                    id: sanitized(section.id) ?? UUID().uuidString,
                    title: sanitized(section.title) ?? "",
                    description: sanitized(section.description) ?? "",
                    items: section.items.compactMap(toItem)
                )
            },
            games: dto.games.compactMap(toGame),
            meta: LibraryCuratorMeta(
                candidateCount: dto.meta.candidateCount,
                selectedCount: dto.meta.selectedCount,
                fallbackReason: sanitized(dto.meta.fallbackReason),
                generatedAt: sanitized(dto.meta.generatedAt) ?? "",
                locale: sanitized(dto.meta.locale) ?? DefaultLanguageProvider.shared.currentLanguageCode
            )
        )
    }

    static func toGame(_ game: LibraryCuratorGame, reason: String? = nil) -> Game? {
        guard let gameId = Int(game.gameId.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: game.rating,
            aggregatedRating: nil,
            totalRating: nil
        )
        let fallbackGenre = L10n.tr("Localizable", "common.label.other")

        return Game(
            id: gameId,
            title: game.title,
            translatedTitle: nil,
            summary: reason,
            translatedSummary: nil,
            genre: game.genres.first ?? fallbackGenre,
            category: game.genres.first ?? fallbackGenre,
            developer: "—",
            platform: game.platforms.first ?? "—",
            releaseDate: nil,
            releaseYear: 0,
            coverImageURL: game.coverURL,
            rating: ratingDisplay.normalizedRating ?? 0,
            reviewCount: 0,
            popularity: game.rating ?? 0,
            isTrending: false,
            formattedRating: ratingDisplay.displayText ?? "—",
            formattedReviewCount: "—"
        )
    }

    private static func toItem(_ dto: LibraryCuratorItemDTO) -> LibraryCuratorItem? {
        guard sanitized(dto.gameId) != nil else { return nil }
        return LibraryCuratorItem(
            gameId: dto.gameId,
            reason: sanitized(dto.reason) ?? "",
            matchTags: sanitized(dto.matchTags),
            confidence: dto.confidence
        )
    }

    private static func toGame(_ dto: LibraryCuratorGameDTO) -> LibraryCuratorGame? {
        guard let gameId = sanitized(dto.gameId) else { return nil }
        return LibraryCuratorGame(
            gameId: gameId,
            title: sanitized(dto.title) ?? L10n.tr("Localizable", "common.label.untitledGame"),
            coverURL: sanitized(dto.coverUrl).flatMap(URL.init(string:)),
            genres: sanitized(dto.genres),
            platforms: sanitized(dto.platforms),
            rating: dto.rating,
            source: sanitized(dto.source),
            playtimeMinutes: dto.playtimeMinutes,
            lastPlayedAt: sanitized(dto.lastPlayedAt),
            isFavorite: dto.isFavorite,
            hasReview: dto.hasReview,
            userRating: dto.userRating
        )
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
