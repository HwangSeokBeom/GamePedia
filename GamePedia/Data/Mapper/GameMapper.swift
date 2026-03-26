import Foundation

// MARK: - GameMapper

enum GameMapper {

    static func toEntity(_ dto: GameDTO) -> Game {
        let releaseDate = Calendar.current.date(from: DateComponents(year: dto.releaseYear, month: 1, day: 1))
        return Game(
            id: dto.id,
            title: dto.title,
            translatedTitle: dto.translatedTitle ?? dto.titleKo,
            summary: nil,
            translatedSummary: nil,
            genre: dto.genre,
            category: dto.genre,
            developer: dto.developer,
            platform: dto.platform,
            releaseDate: releaseDate,
            releaseYear: dto.releaseYear,
            coverImageURL: URL(string: dto.coverImageUrl),
            rating: dto.rating,
            reviewCount: dto.reviewCount,
            popularity: Double(dto.reviewCount),
            isTrending: false,
            formattedRating: String(format: "%.1f", dto.rating),
            formattedReviewCount: dto.reviewCount.abbreviated
        )
    }

    static func toDetailEntity(_ dto: GameDetailDTO) -> GameDetail {
        GameDetail(
            id: dto.id,
            title: dto.title,
            translatedTitle: dto.translatedTitle ?? dto.titleKo,
            genre: dto.genre,
            developer: dto.developer,
            releaseYear: dto.releaseYear,
            coverImageURL: URL(string: dto.coverImageUrl),
            heroImageURL: URL(string: dto.heroImageUrl),
            rating: dto.rating,
            reviewCount: dto.reviewCount,
            avgPlaytimeHours: dto.avgPlaytimeHours,
            summary: dto.description,
            translatedSummary: dto.translatedSummary ?? dto.descriptionKo,
            storyline: dto.description,
            translatedStoryline: dto.translatedStoryline ?? dto.translatedSummary ?? dto.descriptionKo,
            formattedRating: String(format: "%.1f", dto.rating),
            formattedReviewCount: dto.reviewCount.abbreviated,
            formattedPlaytime: "\(dto.avgPlaytimeHours)+ 시간",
            developerLine: "\(dto.developer) · \(dto.genre) · \(dto.releaseYear)"
        )
    }
}
