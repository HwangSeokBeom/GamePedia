import Foundation

// MARK: - GameListResponseDTO

struct GameListResponseDTO: Decodable {
    let games: [GameDTO]
    let total: Int
    let page: Int
}

// MARK: - GameDTO

struct GameDTO: Decodable {
    let id: Int
    let title: String
    /// 한국어 제목 (optional — TODO: confirm API provides this field)
    let titleKo: String?
    let translatedTitle: String?
    let genre: String
    let developer: String
    let platform: String
    let releaseYear: Int
    let coverImageUrl: String
    let rating: Double
    let reviewCount: Int
}

// MARK: - GameDetailDTO

struct GameDetailDTO: Decodable {
    let id: Int
    let title: String
    let titleKo: String?
    let translatedTitle: String?
    let genre: String
    let developer: String
    let releaseYear: Int
    let coverImageUrl: String
    let heroImageUrl: String
    let rating: Double
    let reviewCount: Int
    /// Average playtime in hours (e.g. 60 → displayed as "60+ 시간")
    let avgPlaytimeHours: Int
    let description: String
    /// Korean description — TODO: confirm API provides this field
    let descriptionKo: String?
    let translatedSummary: String?
    let translatedStoryline: String?
}
