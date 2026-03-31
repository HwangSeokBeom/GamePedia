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
}

struct LibraryOverviewResponseDataDTO: Decodable {
    let steamConnected: Bool?
    let steamSyncStatus: String?
    let steamSyncAvailable: Bool?
    let steamSyncErrorCode: String?
    let steamLinkStatus: SteamLinkStatusDTO?
    let recentlyPlayed: [LibraryGameItemDTO]?
    let playing: [LibraryGameItemDTO]?
    let owned: [LibraryGameItemDTO]?
    let backlog: [LibraryGameItemDTO]?
    let liked: [LibraryGameItemDTO]?
    let wishlist: [LibraryGameItemDTO]?
    let reviews: [LibraryReviewedGameItemDTO]?
    let reviewed: [LibraryReviewedGameItemDTO]?
}

struct SteamFriendRecommendationsResponseDataDTO: Decodable {
    let recommendations: [LibraryGameItemDTO]?
}

struct PlaytimeRecommendationsResponseDataDTO: Decodable {
    let recommendations: [LibraryGameItemDTO]?
}

struct LibraryGameItemDTO: Decodable {
    let source: String?
    let gameSource: String?
    let sourceId: String?
    let externalGameId: String?
    let gameId: Int?
    let igdbGameId: String?
    let title: String?
    let gameName: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let translatedTitle: String?
    let coverUrl: String?
    let coverImageUrl: String?
    let genreDisplayName: String?
    let genreSource: String?
    let genre: String?
    let genres: [String]?
    let platform: String?
    let platforms: [String]?
    let releaseYear: Int?
    let releaseDate: Int?
    let rating: Double?
    let aggregatedRating: Double?
    let totalRating: Double?
    let friendCount: Int?
    let reason: String?
    let recentPlaytimeMinutes: Int?
    let recentPlaytimeText: String?
    let playtimeMinutes: Int?
    let userStatus: String?
    let status: String?
    let metadataEnriched: Bool?
    let detailAvailable: Bool?
    let matchStatus: String?
}

struct LibraryReviewedGameItemDTO: Decodable {
    let reviewId: String?
    let rating: Double?
    let content: String?
    let createdAt: String?
    let game: LibraryGameItemDTO?
}

struct UpdateLibraryStatusRequestDTO: Encodable {
    let gameSource: String
    let externalGameId: String
    let title: String
    let coverUrl: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case gameSource = "source"
        case externalGameId
        case title
        case coverUrl
        case status
    }
}

struct LibraryStatusMutationResponseEnvelopeDataDTO: Decodable {
    let libraryEntry: LibraryStatusMutationResponseDataDTO
}

struct LibraryStatusMutationResponseDataDTO: Decodable {
    let source: String?
    let gameSource: String?
    let externalGameId: String?
    let gameId: Int?
    let title: String?
    let gameName: String?
    let coverUrl: String?
    let status: String
    let startedAt: String?
    let completedAt: String?
    let lastPlayedAt: String?
    let playtimeMinutes: Int?
}

struct SyncOwnedSteamLibraryResponseDataDTO: Decodable {
    let syncedCount: Int
    let insertedCount: Int
    let updatedCount: Int
    let syncWarningCode: String?
    let igdbEnrichmentApplied: Bool?
    let igdbEnrichmentSkippedReason: String?
}

struct SteamUnlinkResponseDataDTO: Decodable {
    let unlinked: Bool
    let steamLinkStatus: SteamLinkStatusDTO?
}

struct SteamLinkStartResponseDataDTO: Decodable {
    let steamLink: SteamLinkAuthDTO
}

struct SteamLinkAuthDTO: Decodable {
    let authUrl: String?
}
