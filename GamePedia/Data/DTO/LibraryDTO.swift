import Foundation

struct LibraryResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct SteamLinkStatusDTO: Decodable {
    let isLinked: Bool
    let steamId: String?
    let displayName: String?
    let profileUrl: String?
    let connectUrl: String?
}

struct LibraryOverviewResponseDataDTO: Decodable {
    let steamLinkStatus: SteamLinkStatusDTO?
    let recentlyPlayed: [LibraryGameItemDTO]?
    let playing: [LibraryGameItemDTO]?
    let wishlist: [LibraryGameItemDTO]?
    let reviewed: [LibraryReviewedGameItemDTO]?
}

struct LibraryGameItemDTO: Decodable {
    let source: String?
    let sourceId: String?
    let gameId: Int?
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let translatedTitle: String?
    let coverUrl: String?
    let coverImageUrl: String?
    let genre: String?
    let genres: [String]?
    let platform: String?
    let platforms: [String]?
    let releaseYear: Int?
    let releaseDate: Int?
    let rating: Double?
    let aggregatedRating: Double?
    let totalRating: Double?
    let recentPlaytimeMinutes: Int?
    let recentPlaytimeText: String?
    let userStatus: String?
    let status: String?
}

struct LibraryReviewedGameItemDTO: Decodable {
    let reviewId: String?
    let rating: Double?
    let content: String?
    let createdAt: String?
    let game: LibraryGameItemDTO?
}

struct UpdateLibraryStatusRequestDTO: Encodable {
    let source: String
    let sourceId: String
    let status: String
}

struct LibraryStatusMutationResponseDataDTO: Decodable {
    let source: String?
    let sourceId: String
    let gameId: Int?
    let status: String
}
