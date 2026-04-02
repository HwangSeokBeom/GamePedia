import Foundation

// MARK: - Game (list card model)

struct Game: Hashable {
    let id: Int
    let title: String
    let translatedTitle: String?
    let summary: String?
    let translatedSummary: String?
    let genre: String
    let category: String
    let developer: String
    let platform: String
    let releaseDate: Date?
    let releaseYear: Int
    let coverImageURL: URL?
    let rating: Double
    let reviewCount: Int
    let popularity: Double
    let isTrending: Bool
    let formattedRating: String     // "4.9"
    let formattedReviewCount: String // "12.8K"

    var displayTitle: String { resolvedTitle }

    var resolvedTitle: String {
        title
    }

    var resolvedSummary: String? {
        summary
    }

    func replacingTranslated(
        translatedTitle: String? = nil,
        translatedSummary: String? = nil
    ) -> Game {
        Game(
            id: id,
            title: title,
            translatedTitle: translatedTitle ?? self.translatedTitle,
            summary: summary,
            translatedSummary: translatedSummary ?? self.translatedSummary,
            genre: genre,
            category: category,
            developer: developer,
            platform: platform,
            releaseDate: releaseDate,
            releaseYear: releaseYear,
            coverImageURL: coverImageURL,
            rating: rating,
            reviewCount: reviewCount,
            popularity: popularity,
            isTrending: isTrending,
            formattedRating: formattedRating,
            formattedReviewCount: formattedReviewCount
        )
    }
}

// MARK: - GameDetail (full detail model)

struct GameDetail {
    let id: Int
    let title: String
    let translatedTitle: String?
    let genre: String
    let developer: String
    let releaseYear: Int
    let coverImageURL: URL?
    let heroImageURL: URL?
    let rating: Double
    let reviewCount: Int
    let avgPlaytimeHours: Int
    let summary: String
    let translatedSummary: String?
    let storyline: String
    let translatedStoryline: String?
    let formattedRating: String
    let formattedReviewCount: String
    let formattedPlaytime: String   // "60+ 시간"
    let developerLine: String       // "FromSoftware · 액션 RPG · 2024"
    let hasSteamReview: Bool

    var displayTitle: String { resolvedTitle }
    var displayDescription: String { resolvedSummary }

    var resolvedTitle: String {
        title
    }

    var resolvedSummary: String {
        summary
    }

    var resolvedStoryline: String {
        storyline
    }

    func replacingTranslated(
        translatedTitle: String? = nil,
        translatedSummary: String? = nil,
        translatedStoryline: String? = nil
    ) -> GameDetail {
        GameDetail(
            id: id,
            title: title,
            translatedTitle: translatedTitle ?? self.translatedTitle,
            genre: genre,
            developer: developer,
            releaseYear: releaseYear,
            coverImageURL: coverImageURL,
            heroImageURL: heroImageURL,
            rating: rating,
            reviewCount: reviewCount,
            avgPlaytimeHours: avgPlaytimeHours,
            summary: summary,
            translatedSummary: translatedSummary ?? self.translatedSummary,
            storyline: storyline,
            translatedStoryline: translatedStoryline ?? self.translatedStoryline,
            formattedRating: formattedRating,
            formattedReviewCount: formattedReviewCount,
            formattedPlaytime: formattedPlaytime,
            developerLine: developerLine,
            hasSteamReview: hasSteamReview
        )
    }
}

private extension Game {
    static func resolvedText(_ translated: String?, fallback: String?) -> String? {
        let normalizedTranslated = translated?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedTranslated, !normalizedTranslated.isEmpty {
            return normalizedTranslated
        }

        let normalizedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedFallback, !normalizedFallback.isEmpty {
            return normalizedFallback
        }

        return fallback
    }
}

private extension GameDetail {
    static func resolvedText(_ translated: String?, fallback: String?) -> String? {
        let normalizedTranslated = translated?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedTranslated, !normalizedTranslated.isEmpty {
            return normalizedTranslated
        }

        let normalizedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedFallback, !normalizedFallback.isEmpty {
            return normalizedFallback
        }

        return fallback
    }
}
