import Foundation

enum GameSource: String, Codable, Hashable {
    case steam
    case igdb
}

enum UserGameStatus: String, Codable, CaseIterable, Hashable {
    case wishlist
    case playing
    case completed
    case dropped
}

enum UserGameCollectionSortOption: String, CaseIterable {
    case latest
    case oldest
}

enum LibraryGameMatchStatus: String, Codable, Hashable {
    case confirmed
    case candidate
    case unmatched
    case rejected
    case unknown
}

enum LibraryGameEnrichmentStatus: String, Codable, Hashable {
    case steamOnly = "steam_only"
    case steamPlusIGDBEnriched = "steam_plus_igdb_enriched"
    case enrichmentFailed = "enrichment_failed"
    case enrichmentPending = "enrichment_pending"
    case unknown
}

enum LibraryGenreSource: String, Codable, Hashable {
    case igdb
    case steamTag = "steam_tag"
}

enum SteamLinkConnectionState: Hashable {
    case linked
    case notLinked
}

enum SteamSyncStatus: String, Codable, Hashable {
    case idle
    case notConnected = "not_connected"
    case syncing
    case failed
    case privateProfile = "private_profile"
    case success
    case tokenExpired = "token_expired"
    case unknown
}

struct LibraryGameIdentifier: Hashable {
    let source: GameSource
    let sourceID: String
    let canonicalGameID: Int?

    var uniqueKey: String {
        "\(source.rawValue):\(sourceID)"
    }

    var detailGameID: Int? {
        canonicalGameID ?? (source == .igdb ? Int(sourceID) : nil)
    }

    var steamAppID: String? {
        guard source == .steam else { return nil }
        let normalizedSourceID = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSourceID.isEmpty, normalizedSourceID.allSatisfy(\.isNumber) else { return nil }
        return normalizedSourceID
    }
}

struct SteamLinkStatus: Hashable {
    let connectionState: SteamLinkConnectionState
    let steamID: String?
    let displayName: String?
    let personaName: String?
    let profileURL: URL?
    let canSync: Bool
    let canDisconnect: Bool
    let lastSteamSyncAt: Date?

    var isLinked: Bool {
        connectionState == .linked
    }

    static let notLinked = SteamLinkStatus(
        connectionState: .notLinked,
        steamID: nil,
        displayName: nil,
        personaName: nil,
        profileURL: nil,
        canSync: false,
        canDisconnect: false,
        lastSteamSyncAt: nil
    )
}

struct LibraryGameSummary: Hashable {
    let identifier: LibraryGameIdentifier
    let title: String
    let translatedTitle: String?
    let coverImageURL: URL?
    let fallbackCoverImageURLs: [URL]
    let genre: String
    let genreSource: LibraryGenreSource?
    let platform: String
    let releaseYear: Int
    let rating: Double?
    let recentPlaytimeMinutes: Int?
    let recentPlaytimeText: String?
    let lastPlayedAt: Date?
    let lastPlayedAtSource: String?
    let hasReliableLastPlayedAt: Bool
    let recentPlayFallbackReason: String?
    let playtimeMinutes: Int?
    let userStatus: UserGameStatus?
    let enrichmentStatus: LibraryGameEnrichmentStatus
    let metadataEnriched: Bool
    let detailAvailable: Bool
    let matchStatus: LibraryGameMatchStatus

    var gameSource: GameSource { identifier.source }
    var externalGameId: String { identifier.sourceID }
    var igdbGameId: Int? { identifier.canonicalGameID }
    var formattedRatingText: String? {
        guard let rating, rating.isFinite, rating >= 0 else { return nil }
        return LocalizedNumberFormatter.oneFraction(rating)
    }

    var displayTitle: String { resolvedTitle }

    var resolvedTitle: String {
        title
    }

    var displayableGenreText: String? {
        guard genreSource != nil else { return nil }
        let trimmedGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGenre.isEmpty, trimmedGenre != "기타" else { return nil }
        return trimmedGenre
    }

    var shouldOpenFullGamePediaDetail: Bool {
        switch gameSource {
        case .igdb:
            return igdbGameId != nil
        case .steam:
            return enrichmentStatus == .steamPlusIGDBEnriched && igdbGameId != nil
        }
    }

    var shouldOpenSteamFallbackDetail: Bool {
        guard gameSource == .steam else { return false }

        switch enrichmentStatus {
        case .steamOnly, .enrichmentFailed, .enrichmentPending, .unknown:
            return detailAvailable
        case .steamPlusIGDBEnriched:
            return false
        }
    }

    func replacingTranslatedTitle(_ translatedTitle: String?) -> LibraryGameSummary {
        LibraryGameSummary(
            identifier: identifier,
            title: title,
            translatedTitle: translatedTitle ?? self.translatedTitle,
            coverImageURL: coverImageURL,
            fallbackCoverImageURLs: fallbackCoverImageURLs,
            genre: genre,
            genreSource: genreSource,
            platform: platform,
            releaseYear: releaseYear,
            rating: rating,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            recentPlaytimeText: recentPlaytimeText,
            lastPlayedAt: lastPlayedAt,
            lastPlayedAtSource: lastPlayedAtSource,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlayFallbackReason: recentPlayFallbackReason,
            playtimeMinutes: playtimeMinutes,
            userStatus: userStatus,
            enrichmentStatus: enrichmentStatus,
            metadataEnriched: metadataEnriched,
            detailAvailable: detailAvailable,
            matchStatus: matchStatus
        )
    }

    func replacingRecentPlayMetadata(
        recentPlaytimeMinutes: Int?,
        recentPlaytimeText: String?,
        lastPlayedAt: Date?,
        lastPlayedAtSource: String?,
        hasReliableLastPlayedAt: Bool,
        recentPlayFallbackReason: String?
    ) -> LibraryGameSummary {
        LibraryGameSummary(
            identifier: identifier,
            title: title,
            translatedTitle: translatedTitle,
            coverImageURL: coverImageURL,
            fallbackCoverImageURLs: fallbackCoverImageURLs,
            genre: genre,
            genreSource: genreSource,
            platform: platform,
            releaseYear: releaseYear,
            rating: rating,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            recentPlaytimeText: recentPlaytimeText,
            lastPlayedAt: lastPlayedAt,
            lastPlayedAtSource: lastPlayedAtSource,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlayFallbackReason: recentPlayFallbackReason,
            playtimeMinutes: playtimeMinutes,
            userStatus: userStatus,
            enrichmentStatus: enrichmentStatus,
            metadataEnriched: metadataEnriched,
            detailAvailable: detailAvailable,
            matchStatus: matchStatus
        )
    }

    func replacingRating(_ rating: Double?) -> LibraryGameSummary {
        LibraryGameSummary(
            identifier: identifier,
            title: title,
            translatedTitle: translatedTitle,
            coverImageURL: coverImageURL,
            fallbackCoverImageURLs: fallbackCoverImageURLs,
            genre: genre,
            genreSource: genreSource,
            platform: platform,
            releaseYear: releaseYear,
            rating: rating,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            recentPlaytimeText: recentPlaytimeText,
            lastPlayedAt: lastPlayedAt,
            lastPlayedAtSource: lastPlayedAtSource,
            hasReliableLastPlayedAt: hasReliableLastPlayedAt,
            recentPlayFallbackReason: recentPlayFallbackReason,
            playtimeMinutes: playtimeMinutes,
            userStatus: userStatus,
            enrichmentStatus: enrichmentStatus,
            metadataEnriched: metadataEnriched,
            detailAvailable: detailAvailable,
            matchStatus: matchStatus
        )
    }
}

struct LibraryOverview: Hashable {
    let steamLinkStatus: SteamLinkStatus
    let steamSyncStatus: SteamSyncStatus
    let isSteamSyncAvailable: Bool
    let steamSyncErrorCode: String?
    let recentlyPlayed: [LibraryGameSummary]
    let playing: [LibraryGameSummary]
    let owned: [LibraryGameSummary]
    let backlog: [LibraryGameSummary]
    let playingSummary: LibraryServerSummary?
    let favoritesSummary: LibraryServerSummary?
    let reviewedSummary: LibraryServerSummary?
}

struct LibraryServerSummary: Hashable {
    let totalPlaytimeHours: Double?
    let gameCount: Int?
    let averageRating: Double?
    let reviewCount: Int?
    let totalPlaytimeHoursSourceField: String?
    let gameCountSourceField: String?

    var hasRenderableValues: Bool {
        totalPlaytimeHours != nil || gameCount != nil || averageRating != nil || reviewCount != nil
    }
}

struct OwnedLibraryCollection: Hashable {
    let owned: [LibraryGameSummary]
    let backlog: [LibraryGameSummary]
}

enum LibraryFriendRecommendationSource: String, Codable, Hashable {
    case inAppFriends
    case steamFriends
    case none
}

enum LibraryFriendRecommendationsEmptyState: String, Codable, Hashable {
    case noFriendData
    case insufficientActivity
    case steamUnavailable
}

struct LibraryFriendRecommendationsResult: Hashable {
    let recommendations: [SteamFriendRecommendation]
    let source: LibraryFriendRecommendationSource
    let emptyState: LibraryFriendRecommendationsEmptyState?
}

struct SteamFriendRecommendation: Hashable {
    let game: LibraryGameSummary
    let friendCount: Int
    let reason: String?
}

struct PlaytimeRecommendation: Hashable {
    let game: LibraryGameSummary
    let reason: String?
}

struct LibraryGameStatusUpdateRequest: Hashable {
    let identifier: LibraryGameIdentifier
    let title: String
    let coverImageURL: URL?
    let status: UserGameStatus

    var externalGameId: String {
        identifier.sourceID
    }

    var gameSource: GameSource {
        identifier.source
    }
}

struct LibraryGameStatusMutationResult: Hashable {
    let identifier: LibraryGameIdentifier
    let status: UserGameStatus
}

struct SteamOwnedLibrarySyncResult: Hashable {
    let syncedCount: Int
    let insertedCount: Int
    let updatedCount: Int
    let syncWarningCode: String?
    let igdbEnrichmentApplied: Bool?
    let igdbEnrichmentSkippedReason: String?

    var isRateLimitedIGDBEnrichmentPartialSuccess: Bool {
        syncedCount > 0
            && igdbEnrichmentApplied == false
            && igdbEnrichmentSkippedReason?.uppercased() == "RATE_LIMITED"
    }
}

struct SteamUnlinkResult: Hashable {
    let isUnlinked: Bool
    let steamLinkStatus: SteamLinkStatus
}

enum LibraryError: Error, LocalizedError, Equatable {
    case unauthorized
    case invalidGameIdentifier
    case invalidStatus
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(error: Error) -> LibraryError {
        if let libraryError = error as? LibraryError {
            return libraryError
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .configurationMissing(let message):
                return .server(code: "CONFIGURATION_MISSING", message: message)
            case .unauthorized:
                return .unauthorized
            case .serverError(_, let code, let message):
                let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"
                let resolvedMessage = message ?? L10n.tr("Localizable", "library.error.requestFailed")
                switch resolvedCode {
                case "UNAUTHORIZED":
                    return .unauthorized
                case "INVALID_GAME_ID", "INVALID_SOURCE_ID":
                    return .invalidGameIdentifier
                case "INVALID_EXTERNAL_GAME_ID", "INVALID_GAME_TITLE":
                    return .invalidGameIdentifier
                case "INVALID_STATUS":
                    return .invalidStatus
                default:
                    return .server(code: resolvedCode, message: resolvedMessage)
                }
            case .invalidURL, .noData, .decodingFailed:
                return .invalidResponse
            case .unknown:
                return .network
            }
        }

        if error is URLError {
            return .network
        }

        return .unknown(message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .invalidGameIdentifier:
            return L10n.tr("Localizable", "library.error.invalidGameIdentifier")
        case .invalidStatus:
            return L10n.tr("Localizable", "library.error.invalidStatus")
        case .invalidResponse:
            return L10n.Common.Error.server
        case .network:
            return L10n.Common.Error.network
        case .server(_, let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}

private extension LibraryGameSummary {
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
