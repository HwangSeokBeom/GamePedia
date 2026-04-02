import Foundation

// MARK: - GameMapper

enum GameMapper {

    static func toEntity(_ dto: GameDTO, isTrending: Bool = false) -> Game {
        let selectedRawRating = dto.rating ?? dto.aggregatedRating ?? dto.totalRating
        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: dto.rating,
            aggregatedRating: dto.aggregatedRating,
            totalRating: dto.totalRating
        )

        // When the backend returns originalName, name is the localized display value
        // and originalName is the English original.
        let hasServerTranslation = dto.originalName != nil
        let title = (hasServerTranslation ? dto.originalName : dto.name) ?? "이름 없는 게임"
        let translatedTitle: String? = hasServerTranslation ? dto.name : nil

        let hasServerSummary = dto.originalSummary != nil
        let summary = sanitized(hasServerSummary ? dto.originalSummary : dto.summary)
        let translatedSummary: String? = hasServerSummary ? sanitized(dto.summary) : nil

        return Game(
            id: dto.id,
            title: title,
            translatedTitle: translatedTitle,
            summary: summary,
            translatedSummary: translatedSummary,
            genre: dto.genres?.first ?? "기타",
            category: dto.genres?.first ?? "기타",
            developer: "—",
            platform: dto.platforms?.first ?? "—",
            releaseDate: date(from: dto.releaseDate),
            releaseYear: releaseYear(from: dto.releaseDate),
            coverImageURL: makeURL(from: dto.coverUrl),
            rating: ratingDisplay.normalizedRating ?? 0,
            reviewCount: 0,
            popularity: selectedRawRating ?? 0,
            isTrending: isTrending,
            formattedRating: ratingDisplay.displayText ?? "—",
            formattedReviewCount: "—"
        )
    }

    static func toEntity(_ dto: GameDetailDTO) -> Game {
        let selectedRawRating = dto.rating ?? dto.aggregatedRating ?? dto.totalRating
        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: dto.rating,
            aggregatedRating: dto.aggregatedRating,
            totalRating: dto.totalRating
        )

        return Game(
            id: dto.id,
            title: dto.name ?? "이름 없는 게임",
            translatedTitle: nil,
            summary: sanitized(dto.summary),
            translatedSummary: nil,
            genre: dto.genres?.first ?? "기타",
            category: dto.genres?.first ?? "기타",
            developer: dto.developers?.first ?? dto.publishers?.first ?? "—",
            platform: dto.platforms?.first ?? "—",
            releaseDate: date(from: dto.releaseDate),
            releaseYear: releaseYear(from: dto.releaseDate),
            coverImageURL: makeURL(from: dto.coverUrl),
            rating: ratingDisplay.normalizedRating ?? 0,
            reviewCount: 0,
            popularity: selectedRawRating ?? 0,
            isTrending: false,
            formattedRating: ratingDisplay.displayText ?? "—",
            formattedReviewCount: "—"
        )
    }

    static func toDetailEntity(_ dto: GameDetailDTO) -> GameDetail {
        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: dto.rating,
            aggregatedRating: dto.aggregatedRating,
            totalRating: dto.totalRating
        )
        let userRatingLogValue = dto.rating.map { String($0) } ?? "nil"
        let aggregatedRatingLogValue = dto.aggregatedRating.map { String($0) } ?? "nil"
        let totalRatingLogValue = dto.totalRating.map { String($0) } ?? "nil"
        print(
            "[RatingMapping] " +
            "screen=Game.detailMapper " +
            "title=\(dto.name ?? "게임") " +
            "userRating=\(userRatingLogValue) " +
            "aggregatedRating=\(aggregatedRatingLogValue) " +
            "totalRating=\(totalRatingLogValue) " +
            "selectedDisplaySource=\(ratingDisplay.selectedDisplaySource) " +
            "finalDisplayText=\(ratingDisplay.displayText ?? "nil")"
        )
        let releaseYear = releaseYear(from: dto.releaseDate)
        let developerName = dto.developers?.first ?? dto.publishers?.first ?? "—"
        let genre = dto.genres?.first ?? "기타"
        let summary = sanitized(dto.summary) ?? "소개 정보가 없습니다."
        let storyline = sanitized(dto.storyline) ?? summary

        return GameDetail(
            id: dto.id,
            title: dto.name ?? "이름 없는 게임",
            translatedTitle: nil,
            genre: genre,
            developer: developerName,
            releaseYear: releaseYear,
            coverImageURL: makeURL(from: dto.coverUrl),
            heroImageURL: heroImageURL(from: dto),
            rating: ratingDisplay.normalizedRating ?? 0,
            reviewCount: 0,
            avgPlaytimeHours: 0,
            summary: summary,
            translatedSummary: nil,
            storyline: storyline,
            translatedStoryline: nil,
            formattedRating: ratingDisplay.displayText ?? "—",
            formattedReviewCount: "—",
            formattedPlaytime: "—",
            developerLine: "\(developerName) · \(genre) · \(releaseYear)",
            hasSteamReview: dto.hasSteamReview ?? false
        )
    }

    private static func releaseYear(from unixTimestamp: Int?) -> Int {
        guard let unixTimestamp else { return 0 }
        let date = Date(timeIntervalSince1970: TimeInterval(unixTimestamp))
        return Calendar.current.component(.year, from: date)
    }

    private static func date(from unixTimestamp: Int?) -> Date? {
        guard let unixTimestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(unixTimestamp))
    }

    private static func makeURL(from rawURL: String?) -> URL? {
        guard let rawURL = sanitized(rawURL) else { return nil }
        return URL(string: rawURL)
    }

    private static func heroImageURL(from dto: GameDetailDTO) -> URL? {
        if let screenshotURL = dto.screenshotUrls?.first,
           let url = makeURL(from: screenshotURL) {
            return url
        }

        if let artworkURL = dto.artworkUrls?.first,
           let url = makeURL(from: artworkURL) {
            return url
        }

        return makeURL(from: dto.coverUrl)
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
