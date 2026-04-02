import Foundation

// MARK: - IGDBGameMapper

enum IGDBGameMapper {

    // MARK: - IGDBGameDTO → Game (list card)

    static func toEntity(_ dto: IGDBGameDTO) -> Game {
        // IGDB rating is 0–100. Convert to 0–5 so StarRatingView works without extra math.
        let ratingOn5Scale = (dto.rating ?? 0) / 20.0
        let releaseDate = date(from: dto.firstReleaseDate)
        let reviewCount = dto.ratingCount ?? 0
        return Game(
            id: dto.id,
            title: dto.name,
            translatedTitle: dto.translatedTitle,
            summary: dto.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
            translatedSummary: dto.translatedSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
            genre: dto.genres?.first?.name ?? "기타",
            category: dto.genres?.first?.name ?? "기타",
            developer: "—",         // not fetched in list query — populated in detail
            platform: dto.platforms?.first?.name ?? "—",
            releaseDate: releaseDate,
            releaseYear: releaseYear(from: dto.firstReleaseDate),
            coverImageURL: coverURL(from: dto.cover?.url),
            rating: ratingOn5Scale,
            reviewCount: reviewCount,
            popularity: popularity(from: dto),
            isTrending: (dto.hypes ?? 0) > 0,
            formattedRating: formattedRating5(ratingOn5Scale, hasRating: dto.rating != nil),
            formattedReviewCount: reviewCount > 0 ? reviewCount.abbreviated : "—"
        )
    }

    // MARK: - IGDBGameDetailDTO → GameDetail

    static func toDetailEntity(_ dto: IGDBGameDetailDTO) -> GameDetail {
        let developerName = dto.involvedCompanies?
            .first(where: { $0.developer == true })?
            .company?.name ?? "—"

        let genreName = dto.genres?.first?.name ?? "기타"
        let year = releaseYear(from: dto.firstReleaseDate)
        let ratingOn5Scale = (dto.rating ?? 0) / 20.0
        let ratingCount = dto.ratingCount ?? 0

        return GameDetail(
            id: dto.id,
            title: dto.name,
            translatedTitle: dto.translatedTitle,
            genre: genreName,
            developer: developerName,
            releaseYear: year,
            coverImageURL: coverURL(from: dto.cover?.url),
            heroImageURL: heroURL(from: dto.screenshots?.first?.url ?? dto.cover?.url),
            rating: ratingOn5Scale,
            reviewCount: ratingCount,
            avgPlaytimeHours: 0,        // TODO: IGDB doesn't provide playtime — integrate HLTB API if needed
            summary: dto.summary ?? "소개 정보가 없습니다.",
            translatedSummary: dto.translatedSummary,
            storyline: dto.summary ?? "소개 정보가 없습니다.",
            translatedStoryline: dto.translatedStoryline ?? dto.translatedSummary,
            formattedRating: formattedRating5(ratingOn5Scale, hasRating: dto.rating != nil),
            formattedReviewCount: ratingCount.abbreviated,
            formattedPlaytime: "—",
            developerLine: "\(developerName) · \(genreName) · \(year)"
        )
    }

    // MARK: - Cover URL Helpers

    /// Converts a protocol-relative IGDB URL to a full HTTPS URL.
    /// Also replaces the image size slug with AppConfig.igdbImageSize.
    ///
    /// Input:  "//images.igdb.com/igdb/image/upload/t_thumb/co5ptl.jpg"
    /// Output: "https://images.igdb.com/igdb/image/upload/t_cover_big/co5ptl.jpg"
    static func coverURL(from rawURL: String?) -> URL? {
        guard let rawURL else { return nil }
        let withProtocol = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
        let resized = withProtocol.replacingOccurrences(of: "t_thumb", with: AppConfig.igdbImageSize)
        return URL(string: resized)
    }

    /// For hero images (screenshots or cover), uses a larger size.
    static func heroURL(from rawURL: String?) -> URL? {
        guard let rawURL else { return nil }
        let withProtocol = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
        let resized = withProtocol
            .replacingOccurrences(of: "t_thumb", with: "t_1080p")
            .replacingOccurrences(of: "t_screenshot_med", with: "t_1080p")
        return URL(string: resized)
    }

    // MARK: - Private Helpers

    private static func releaseYear(from unixTimestamp: Int?) -> Int {
        guard let timestamp = unixTimestamp else { return 0 }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return Calendar.current.component(.year, from: date)
    }

    private static func date(from unixTimestamp: Int?) -> Date? {
        guard let timestamp = unixTimestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private static func popularity(from dto: IGDBGameDTO) -> Double {
        if let hypes = dto.hypes, hypes > 0 { return Double(hypes) }
        if let ratingCount = dto.ratingCount, ratingCount > 0 { return Double(ratingCount) }
        return dto.rating ?? 0
    }

    /// Formats a 0–5 scale rating. Returns "—" when IGDB provided no rating.
    private static func formattedRating5(_ ratingOn5: Double, hasRating: Bool) -> String {
        guard hasRating else { return "—" }
        return String(format: "%.1f", ratingOn5)
    }
}
