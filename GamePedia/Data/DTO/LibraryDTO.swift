import Foundation

struct LibraryResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct SteamLinkStatusDTO: Decodable {
    let isLinked: Bool
    let steamId: String?
    let displayName: String?
    let personaName: String?
    let profileUrl: String?
    let canSync: Bool?
    let canDisconnect: Bool?
    let lastSteamSyncAt: String?
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
    let playingSummary: LibraryTabSummaryDTO?
    let favoritesSummary: LibraryTabSummaryDTO?
    let reviewedSummary: LibraryTabSummaryDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        steamConnected = try container.decodeIfPresent(Bool.self, forKey: .steamConnected)
        steamSyncStatus = try container.decodeIfPresent(String.self, forKey: .steamSyncStatus)
        steamSyncAvailable = try container.decodeIfPresent(Bool.self, forKey: .steamSyncAvailable)
        steamSyncErrorCode = try container.decodeIfPresent(String.self, forKey: .steamSyncErrorCode)
        steamLinkStatus = try container.decodeIfPresent(SteamLinkStatusDTO.self, forKey: .steamLinkStatus)
        recentlyPlayed = try container.decodeIfPresent([LibraryGameItemDTO].self, forKey: .recentlyPlayed)
        playing = try container.decodeIfPresent([LibraryGameItemDTO].self, forKey: .playing)
        owned = try container.decodeIfPresent([LibraryGameItemDTO].self, forKey: .owned)
        backlog = try container.decodeIfPresent([LibraryGameItemDTO].self, forKey: .backlog)
        liked = try container.decodeIfPresent([LibraryGameItemDTO].self, forKey: .liked)
        wishlist = try container.decodeIfPresent([LibraryGameItemDTO].self, forKey: .wishlist)
        reviews = try container.decodeIfPresent([LibraryReviewedGameItemDTO].self, forKey: .reviews)
        reviewed = try container.decodeIfPresent([LibraryReviewedGameItemDTO].self, forKey: .reviewed)
        playingSummary = Self.decodeSummary(
            container: container,
            directKeys: [.playingSummary, .previewSummary, .preview],
            nestedKeys: [.playing]
        )
        favoritesSummary = Self.decodeSummary(
            container: container,
            directKeys: [.favoritesSummary],
            nestedKeys: [.favorites, .wishlist, .liked]
        )
        reviewedSummary = Self.decodeSummary(
            container: container,
            directKeys: [.reviewedSummary],
            nestedKeys: [.reviewed, .reviews]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case steamConnected
        case steamSyncStatus
        case steamSyncAvailable
        case steamSyncErrorCode
        case steamLinkStatus
        case recentlyPlayed
        case playing
        case owned
        case backlog
        case liked
        case wishlist
        case reviews
        case reviewed
        case summary
        case summaries
        case preview
        case previewSummary
        case playingSummary
        case favoritesSummary
        case reviewedSummary
    }

    private enum NestedSummaryKeys: String, CodingKey {
        case playing
        case favorites
        case wishlist
        case liked
        case reviewed
        case reviews
    }

    private enum NestedPreviewKeys: String, CodingKey {
        case summary
        case summaries
        case playing
        case favorites
        case wishlist
        case liked
        case reviewed
        case reviews
        case playingSummary
        case favoritesSummary
        case reviewedSummary
    }

    private static func decodeSummary(
        container: KeyedDecodingContainer<CodingKeys>,
        directKeys: [CodingKeys],
        nestedKeys: [NestedSummaryKeys]
    ) -> LibraryTabSummaryDTO? {
        for directKey in directKeys {
            if let summary = try? container.decodeIfPresent(LibraryTabSummaryDTO.self, forKey: directKey) {
                return summary
            }

            if let previewContainer = try? container.nestedContainer(keyedBy: NestedPreviewKeys.self, forKey: directKey) {
                for previewKey in [NestedPreviewKeys.playingSummary, .favoritesSummary, .reviewedSummary] {
                    if let summary = try? previewContainer.decodeIfPresent(LibraryTabSummaryDTO.self, forKey: previewKey) {
                        return summary
                    }
                }

                for previewKey in [NestedPreviewKeys.playing, .favorites, .wishlist, .liked, .reviewed, .reviews] {
                    if let summary = try? previewContainer.decodeIfPresent(LibraryTabSummaryDTO.self, forKey: previewKey) {
                        return summary
                    }
                }

                for previewParentKey in [NestedPreviewKeys.summary, NestedPreviewKeys.summaries] {
                    if let summaryDecoder = try? previewContainer.superDecoder(forKey: previewParentKey),
                       let summary = try? LibraryTabSummaryDTO(from: summaryDecoder) {
                        if summary.hasRenderableValues {
                            return summary
                        }
                    }

                    guard let nestedContainer = try? previewContainer.nestedContainer(keyedBy: NestedSummaryKeys.self, forKey: previewParentKey) else {
                        continue
                    }

                    for nestedKey in nestedKeys {
                        if let summary = try? nestedContainer.decodeIfPresent(LibraryTabSummaryDTO.self, forKey: nestedKey) {
                            return summary
                        }
                    }
                }
            }
        }

        for parentKey in [CodingKeys.summary, CodingKeys.summaries, CodingKeys.preview, CodingKeys.previewSummary] {
            if let summaryDecoder = try? container.superDecoder(forKey: parentKey),
               let summary = try? LibraryTabSummaryDTO(from: summaryDecoder) {
                if summary.hasRenderableValues {
                    return summary
                }
            }

            guard let nestedContainer = try? container.nestedContainer(keyedBy: NestedSummaryKeys.self, forKey: parentKey) else {
                continue
            }

            for nestedKey in nestedKeys {
                if let summary = try? nestedContainer.decodeIfPresent(LibraryTabSummaryDTO.self, forKey: nestedKey) {
                    return summary
                }
            }
        }

        return nil
    }
}

struct LibraryTabSummaryDTO: Decodable {
    let gameCount: Int?
    let totalPlaytimeHours: Double?
    let totalPlaytimeMinutes: Double?
    let averageRating: Double?
    let reviewCount: Int?
    let gameCountSourceField: String?
    let totalPlaytimeHoursSourceField: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let gameCountResult = Self.decodeInt(
            container,
            keys: [.gameCount, .count, .gamesCount, .playedGameCount, .game_count, .games_count, .totalGames]
        )
        let totalPlaytimeHoursResult = Self.decodeDouble(
            container,
            keys: [.totalPlaytimeHours, .playtimeHours, .totalHours, .totalPlaytime, .total_playtime_hours, .playtime_hours]
        )
        let totalPlaytimeMinutesResult = Self.decodeDouble(
            container,
            keys: [.totalPlaytimeMinutes, .playtimeMinutes, .total_playtime_minutes, .playtime_minutes]
        )
        let averageRatingResult = Self.decodeDouble(
            container,
            keys: [.averageRating, .avgRating, .ratingAverage, .average_rating, .avg_rating]
        )
        let reviewCountResult = Self.decodeInt(
            container,
            keys: [.reviewCount, .reviewsCount, .review_count, .reviews_count]
        )

        gameCount = gameCountResult.value
        totalPlaytimeMinutes = totalPlaytimeMinutesResult.value
        if let totalPlaytimeHoursValue = totalPlaytimeHoursResult.value {
            totalPlaytimeHours = totalPlaytimeHoursValue
        } else if let totalPlaytimeMinutesValue = totalPlaytimeMinutesResult.value {
            totalPlaytimeHours = totalPlaytimeMinutesValue / 60
        } else {
            totalPlaytimeHours = nil
        }
        averageRating = averageRatingResult.value
        reviewCount = reviewCountResult.value
        gameCountSourceField = gameCountResult.sourceField
        totalPlaytimeHoursSourceField = totalPlaytimeHoursResult.sourceField ?? totalPlaytimeMinutesResult.sourceField
    }

    private enum CodingKeys: String, CodingKey {
        case gameCount
        case count
        case gamesCount
        case playedGameCount
        case game_count
        case games_count
        case totalGames
        case totalPlaytimeHours
        case playtimeHours
        case totalHours
        case totalPlaytime
        case totalPlaytimeMinutes
        case playtimeMinutes
        case total_playtime_hours
        case playtime_hours
        case total_playtime_minutes
        case playtime_minutes
        case averageRating
        case avgRating
        case ratingAverage
        case average_rating
        case avg_rating
        case reviewCount
        case reviewsCount
        case review_count
        case reviews_count
    }

    var hasRenderableValues: Bool {
        gameCount != nil || totalPlaytimeHours != nil || totalPlaytimeMinutes != nil || averageRating != nil || reviewCount != nil
    }

    private static func decodeInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> (value: Int?, sourceField: String?) {
        for key in keys {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return (value, key.stringValue)
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let intValue = Int(value) {
                return (intValue, key.stringValue)
            }
        }
        return (nil, nil)
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> (value: Double?, sourceField: String?) {
        for key in keys {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return (value, key.stringValue)
            }
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return (Double(value), key.stringValue)
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let doubleValue = Double(value) {
                return (doubleValue, key.stringValue)
            }
        }
        return (nil, nil)
    }
}

struct LibraryFriendRecommendationsResponseDataDTO: Decodable {
    let recommendations: [LibraryGameItemDTO]?
}

typealias SteamFriendRecommendationsResponseDataDTO = LibraryFriendRecommendationsResponseDataDTO

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
    let lastPlayedAt: String?
    let lastPlayedAtSource: String?
    let hasReliableLastPlayedAt: Bool?
    let fallbackReason: String?
    let inclusionSource: String?
    let playtimeMinutes: Int?
    let userStatus: String?
    let status: String?
    let enrichmentStatus: String?
    let metadataEnriched: Bool?
    let detailAvailable: Bool?
    let matchStatus: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nestedGame = try? container.decodeIfPresent(NestedLibraryGameDTO.self, forKey: .game)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        gameSource = try container.decodeIfPresent(String.self, forKey: .gameSource) ?? nestedGame?.gameSource
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId) ?? nestedGame?.sourceId
        externalGameId = try container.decodeIfPresent(String.self, forKey: .externalGameId) ?? nestedGame?.externalGameId
        gameId = try Self.decodeInt(container, keys: [.gameId, .igdbNumericId]) ?? nestedGame?.resolvedGameId
        igdbGameId = try container.decodeIfPresent(String.self, forKey: .igdbGameId) ?? nestedGame?.igdbGameId
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? nestedGame?.title
        gameName = try container.decodeIfPresent(String.self, forKey: .gameName) ?? nestedGame?.gameName
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? nestedGame?.name
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle) ?? nestedGame?.originalTitle
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName) ?? nestedGame?.originalName
        translatedTitle = try container.decodeIfPresent(String.self, forKey: .translatedTitle) ?? nestedGame?.translatedTitle
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl) ?? nestedGame?.coverUrl
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl) ?? nestedGame?.coverImageUrl
        genreDisplayName = try container.decodeIfPresent(String.self, forKey: .genreDisplayName) ?? nestedGame?.genreDisplayName
        genreSource = try container.decodeIfPresent(String.self, forKey: .genreSource) ?? nestedGame?.genreSource
        genre = try container.decodeIfPresent(String.self, forKey: .genre) ?? nestedGame?.genre
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? nestedGame?.genres
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? nestedGame?.platform
        platforms = try container.decodeIfPresent([String].self, forKey: .platforms) ?? nestedGame?.platforms
        releaseYear = try container.decodeIfPresent(Int.self, forKey: .releaseYear) ?? nestedGame?.releaseYear
        releaseDate = try container.decodeIfPresent(Int.self, forKey: .releaseDate) ?? nestedGame?.releaseDate

        let topLevelRating = try Self.decodeDouble(container, keys: [.rating, .igdbRating, .igdb_score])
        let aggregatedRatingValue = try Self.decodeDouble(container, keys: [.aggregatedRating, .aggregated_rating])
        let totalRatingValue = try Self.decodeDouble(container, keys: [.totalRating, .total_rating])
        let nestedTopLevelRating = nestedGame?.rating
        let nestedAggregatedRating = nestedGame?.aggregatedRating
        let nestedTotalRating = nestedGame?.totalRating
        if let nestedRatingContainer = try? container.nestedContainer(keyedBy: NestedRatingCodingKeys.self, forKey: .metadata) {
            let nestedRating = try Self.decodeDouble(nestedRatingContainer, keys: [.rating, .igdbRating, .igdb_score])
            let nestedMetadataAggregatedRating = try Self.decodeDouble(nestedRatingContainer, keys: [.aggregatedRating, .aggregated_rating])
            let nestedMetadataTotalRating = try Self.decodeDouble(nestedRatingContainer, keys: [.totalRating, .total_rating])
            rating = topLevelRating ?? nestedRating ?? nestedTopLevelRating
            aggregatedRating = aggregatedRatingValue ?? nestedMetadataAggregatedRating ?? nestedAggregatedRating
            totalRating = totalRatingValue ?? nestedMetadataTotalRating ?? nestedTotalRating
        } else {
            rating = topLevelRating ?? nestedTopLevelRating
            aggregatedRating = aggregatedRatingValue ?? nestedAggregatedRating
            totalRating = totalRatingValue ?? nestedTotalRating
        }

        friendCount = try container.decodeIfPresent(Int.self, forKey: .friendCount)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        recentPlaytimeMinutes = try Self.decodeInt(
            container,
            keys: [.recentPlaytimeMinutes, .recent_playtime_minutes]
        )
        recentPlaytimeText = try Self.decodeString(
            container,
            keys: [.recentPlaytimeText, .recent_playtime_text]
        )
        lastPlayedAt = try Self.decodeString(
            container,
            keys: [.lastPlayedAt, .playedAt, .last_played_at, .played_at]
        )
        lastPlayedAtSource = try Self.decodeString(
            container,
            keys: [.lastPlayedAtSource, .playedAtSource, .last_played_at_source, .played_at_source]
        )
        hasReliableLastPlayedAt = try Self.decodeBool(
            container,
            keys: [.hasReliableLastPlayedAt, .isReliableLastPlayedAt, .has_reliable_last_played_at, .is_reliable_last_played_at]
        )
        fallbackReason = try Self.decodeString(
            container,
            keys: [.fallbackReason, .fallback_reason]
        )
        inclusionSource = try Self.decodeString(
            container,
            keys: [.inclusionSource, .inclusion_source]
        )
        playtimeMinutes = try container.decodeIfPresent(Int.self, forKey: .playtimeMinutes)
        userStatus = try container.decodeIfPresent(String.self, forKey: .userStatus)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        enrichmentStatus = try container.decodeIfPresent(String.self, forKey: .enrichmentStatus)
        metadataEnriched = try container.decodeIfPresent(Bool.self, forKey: .metadataEnriched)
        detailAvailable = try container.decodeIfPresent(Bool.self, forKey: .detailAvailable) ?? nestedGame?.detailAvailable
        matchStatus = try container.decodeIfPresent(String.self, forKey: .matchStatus) ?? nestedGame?.matchStatus
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case gameSource
        case sourceId
        case externalGameId
        case gameId
        case igdbNumericId = "igdb_id"
        case igdbGameId
        case title
        case gameName
        case name
        case originalTitle
        case originalName
        case translatedTitle
        case coverUrl
        case coverImageUrl
        case genreDisplayName
        case genreSource
        case genre
        case genres
        case platform
        case platforms
        case releaseYear
        case releaseDate
        case rating
        case igdbRating
        case igdb_score
        case aggregatedRating
        case aggregated_rating
        case totalRating
        case total_rating
        case metadata
        case game
        case friendCount
        case reason
        case recentPlaytimeMinutes
        case recent_playtime_minutes
        case recentPlaytimeText
        case recent_playtime_text
        case lastPlayedAt
        case playedAt
        case last_played_at
        case played_at
        case lastPlayedAtSource
        case playedAtSource
        case last_played_at_source
        case played_at_source
        case hasReliableLastPlayedAt
        case isReliableLastPlayedAt
        case has_reliable_last_played_at
        case is_reliable_last_played_at
        case fallbackReason
        case fallback_reason
        case inclusionSource
        case inclusion_source
        case playtimeMinutes
        case userStatus
        case status
        case enrichmentStatus
        case metadataEnriched
        case detailAvailable
        case matchStatus
    }

    private enum NestedRatingCodingKeys: String, CodingKey {
        case rating
        case igdbRating
        case igdb_score
        case aggregatedRating
        case aggregated_rating
        case totalRating
        case total_rating
    }

    private static func decodeInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> Int? {
        for key in keys {
            if let value = try container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try container.decodeIfPresent(String.self, forKey: key),
               let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }

    private static func decodeString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> String? {
        for key in keys {
            if let value = try container.decodeIfPresent(String.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> Bool? {
        for key in keys {
            if let value = try container.decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> Double? {
        for key in keys {
            if let value = try container.decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try container.decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try container.decodeIfPresent(String.self, forKey: key),
               let doubleValue = Double(value) {
                return doubleValue
            }
        }
        return nil
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<NestedRatingCodingKeys>,
        keys: [NestedRatingCodingKeys]
    ) throws -> Double? {
        for key in keys {
            if let value = try container.decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try container.decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try container.decodeIfPresent(String.self, forKey: key),
               let doubleValue = Double(value) {
                return doubleValue
            }
        }
        return nil
    }
}

private struct NestedLibraryGameDTO: Decodable {
    let id: Int?
    let igdbGameId: String?
    let sourceId: String?
    let externalGameId: String?
    let gameSource: String?
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
    let detailAvailable: Bool?
    let matchStatus: String?

    var resolvedGameId: Int? {
        if let id, id > 0 { return id }
        if let igdbGameId, let resolved = Int(igdbGameId), resolved > 0 { return resolved }
        return nil
    }
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
