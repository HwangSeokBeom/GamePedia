import Foundation

struct GameResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct GameListResponseDataDTO: Decodable {
    let games: [GameDTO]
    let query: String?
}

struct GameDetailResponseDataDTO: Decodable {
    let game: GameDetailDTO
}

struct GameDTO: Decodable {
    let id: Int
    let name: String?
    let originalName: String?
    let summary: String?
    let originalSummary: String?
    let coverUrl: String?
    let genres: [String]?
    let platforms: [String]?
    let rating: Double?
    let aggregatedRating: Double?
    let totalRating: Double?
    let releaseDate: Int?
}

struct GameDetailDTO: Decodable {
    let id: Int
    let name: String?
    let summary: String?
    let storyline: String?
    let coverUrl: String?
    let artworkUrls: [String]?
    let screenshotUrls: [String]?
    let genres: [String]?
    let platforms: [String]?
    let developers: [String]?
    let publishers: [String]?
    let rating: Double?
    let aggregatedRating: Double?
    let totalRating: Double?
    let releaseDate: Int?
    let status: Int?
    let category: Int?
    let videoIds: [String]?
    let similarGames: [GameDTO]?
}
