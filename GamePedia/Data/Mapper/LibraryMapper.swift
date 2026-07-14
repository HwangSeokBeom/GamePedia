import Foundation

enum LibraryMapper {

    static func toSteamLinkStatus(_ dto: SteamLinkStatusDTO?) -> SteamLinkStatus {
        guard let dto else { return .notLinked }

        return SteamLinkStatus(
            connectionState: dto.isLinked ? .linked : .notLinked,
            steamID: sanitized(dto.steamId),
            displayName: sanitized(dto.displayName),
            personaName: sanitized(dto.personaName),
            profileURL: makeURL(from: dto.profileUrl),
            canSync: dto.canSync ?? dto.isLinked,
            canDisconnect: dto.canDisconnect ?? dto.isLinked,
            lastSteamSyncAt: parseDate(dto.lastSteamSyncAt)
        )
    }

    static func toGameSummary(_ dto: LibraryGameItemDTO) throws -> LibraryGameSummary {
        let source = resolvedSource(from: dto.gameSource ?? dto.source)
        let canonicalGameID = resolvedIGDBGameID(from: dto)
        let resolvedSourceID = resolvedSourceID(from: dto, source: source)
        guard let resolvedSourceID else {
            print(
                "[Library] invalidGameIdentifier " +
                "source=\(dto.source ?? "nil") " +
                "sourceId=\(dto.sourceId ?? "nil") " +
                "gameId=\(dto.gameId.map(String.init) ?? "nil") " +
                "title=\(dto.title ?? dto.name ?? "nil")"
            )
            throw LibraryError.invalidGameIdentifier
        }

        let title = resolvedTitle(from: dto)
        let translatedTitle = resolvedTranslatedTitle(from: dto, fallbackTitle: title)
        let genre = resolvedGenre(from: dto) ?? ""
        let platform = sanitized(dto.platform) ?? dto.platforms?.first ?? defaultPlatform(for: source)
        let releaseYear = resolvedReleaseYear(from: dto)
        let enrichmentStatus = resolvedEnrichmentStatus(
            from: dto.enrichmentStatus,
            source: source
        )
        let metadataEnriched = resolvedMetadataEnriched(
            from: dto.metadataEnriched,
            source: source,
            enrichmentStatus: enrichmentStatus,
            igdbGameID: canonicalGameID
        )
        let genreSource = resolvedGenreSource(
            from: dto,
            source: source,
            igdbGameID: canonicalGameID,
            metadataEnriched: metadataEnriched,
            hasGenre: !genre.isEmpty
        )
        let detailAvailable = dto.detailAvailable ?? defaultDetailAvailability(
            source: source,
            externalGameId: sanitized(dto.externalGameId) ?? resolvedSourceID,
            igdbGameID: canonicalGameID
        )
        let matchStatus = resolvedMatchStatus(
            from: dto.matchStatus,
            source: source,
            igdbGameID: canonicalGameID,
            metadataEnriched: metadataEnriched,
            detailAvailable: detailAvailable
        )
        let resolvedIGDBCoverURL = igdbCoverURL(from: dto.coverUrl ?? dto.coverImageUrl)
        let resolvedImageURLs = source == .steam
            ? LibraryGameImageURLResolver.resolveImageURLs(
                gameSource: source,
                externalGameId: resolvedSteamAppID(from: dto, fallbackSourceID: resolvedSourceID),
                igdbCoverUrl: resolvedIGDBCoverURL
            )
            : LibraryResolvedImageURLs(
                primaryURL: makeURL(from: dto.coverUrl ?? dto.coverImageUrl),
                fallbackURLs: []
            )

        let ratingDisplay = GameRatingDisplayFormatter.makeDisplay(
            userRating: dto.rating,
            aggregatedRating: dto.aggregatedRating,
            totalRating: dto.totalRating
        )
        let summary = LibraryGameSummary(
            identifier: LibraryGameIdentifier(
                source: source,
                sourceID: resolvedSourceID,
                canonicalGameID: canonicalGameID
            ),
            title: title,
            translatedTitle: translatedTitle,
            coverImageURL: resolvedImageURLs.primaryURL,
            fallbackCoverImageURLs: resolvedImageURLs.fallbackURLs,
            genre: genre,
            genreSource: genreSource,
            platform: platform,
            releaseYear: releaseYear,
            rating: ratingDisplay.normalizedRating,
            recentPlaytimeMinutes: dto.recentPlaytimeMinutes,
            recentPlaytimeText: resolvedRecentPlaytimeText(from: dto),
            lastPlayedAt: parseDate(dto.lastPlayedAt),
            lastPlayedAtSource: sanitized(dto.lastPlayedAtSource),
            hasReliableLastPlayedAt: resolvedReliableLastPlayedAt(from: dto),
            recentPlayFallbackReason: sanitized(dto.fallbackReason),
            playtimeMinutes: dto.playtimeMinutes,
            userStatus: resolvedStatus(from: dto.userStatus ?? dto.status),
            enrichmentStatus: enrichmentStatus,
            metadataEnriched: metadataEnriched,
            detailAvailable: detailAvailable,
            matchStatus: matchStatus
        )
        let userRatingLogValue = dto.rating.map { String($0) } ?? "nil"
        let aggregatedRatingLogValue = dto.aggregatedRating.map { String($0) } ?? "nil"
        let totalRatingLogValue = dto.totalRating.map { String($0) } ?? "nil"
        print(
            "[RatingMapping] " +
            "screen=Library.mapper " +
            "title=\(summary.displayTitle) " +
            "userRating=\(userRatingLogValue) " +
            "aggregatedRating=\(aggregatedRatingLogValue) " +
            "totalRating=\(totalRatingLogValue) " +
            "selectedDisplaySource=\(ratingDisplay.selectedDisplaySource) " +
            "finalDisplayText=\(ratingDisplay.displayText ?? "nil")"
        )
        print(
            "[RecentPlayMapping] " +
            "screen=Library.mapper " +
            "title=\(summary.displayTitle) " +
            "viewState.lastPlayedAt=\(summary.lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil") " +
            "viewState.recentPlaytimeMinutes=\(summary.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
            "viewState.hasReliableLastPlayedAt=\(summary.hasReliableLastPlayedAt)"
        )
        return summary
    }

    static func toStatusMutationResult(_ dto: LibraryStatusMutationResponseDataDTO) throws -> LibraryGameStatusMutationResult {
        guard let status = UserGameStatus(rawValue: dto.status.lowercased()) else {
            throw LibraryError.invalidStatus
        }

        guard let sourceID = sanitized(dto.externalGameId) ?? dto.gameId.map(String.init) else {
            throw LibraryError.invalidGameIdentifier
        }

        return LibraryGameStatusMutationResult(
            identifier: LibraryGameIdentifier(
                source: resolvedSource(from: dto.source ?? dto.gameSource),
                sourceID: sourceID,
                canonicalGameID: dto.gameId
            ),
            status: status
        )
    }

    static func toSteamLinkURL(_ dto: SteamLinkStartResponseDataDTO) throws -> URL {
        guard let authURL = makeURL(from: dto.steamLink.authUrl) else {
            throw LibraryError.invalidResponse
        }

        return authURL
    }

    private static func resolvedSourceID(from dto: LibraryGameItemDTO, source: GameSource) -> String? {
        if let sourceId = sanitized(dto.sourceId) {
            return sourceId
        }

        if let externalGameId = sanitized(dto.externalGameId) {
            return externalGameId
        }

        if let gameId = dto.gameId {
            return String(gameId)
        }

        if source == .steam, let title = sanitized(dto.title ?? dto.name) {
            return title
        }

        return nil
    }

    private static func resolvedTitle(from dto: LibraryGameItemDTO) -> String {
        sanitized(dto.originalTitle)
            ?? sanitized(dto.originalName)
            ?? sanitized(dto.gameName)
            ?? sanitized(dto.title)
            ?? sanitized(dto.name)
            ?? L10n.tr("Localizable", "common.label.untitledGame")
    }

    private static func resolvedTranslatedTitle(from dto: LibraryGameItemDTO, fallbackTitle: String) -> String? {
        _ = dto
        _ = fallbackTitle
        return nil
    }

    private static func resolvedSource(from rawValue: String?) -> GameSource {
        guard let rawValue = sanitized(rawValue)?.lowercased(),
              let source = GameSource(rawValue: rawValue) else {
            return .igdb
        }
        return source
    }

    private static func resolvedStatus(from rawValue: String?) -> UserGameStatus? {
        guard let rawValue = sanitized(rawValue)?.lowercased() else { return nil }
        return UserGameStatus(rawValue: rawValue)
    }

    private static func resolvedEnrichmentStatus(
        from rawValue: String?,
        source: GameSource
    ) -> LibraryGameEnrichmentStatus {
        if let rawValue = sanitized(rawValue)?.lowercased(),
           let enrichmentStatus = LibraryGameEnrichmentStatus(rawValue: rawValue) {
            return enrichmentStatus
        }

        switch source {
        case .igdb:
            return .steamPlusIGDBEnriched
        case .steam:
            return .unknown
        }
    }

    private static func resolvedMetadataEnriched(
        from rawValue: Bool?,
        source: GameSource,
        enrichmentStatus: LibraryGameEnrichmentStatus,
        igdbGameID: Int?
    ) -> Bool {
        if source == .igdb {
            return rawValue ?? (igdbGameID != nil)
        }

        switch enrichmentStatus {
        case .steamPlusIGDBEnriched:
            return true
        case .steamOnly, .enrichmentFailed, .enrichmentPending, .unknown:
            return false
        }
    }

    private static func resolvedMatchStatus(
        from rawValue: String?,
        source: GameSource,
        igdbGameID: Int?,
        metadataEnriched: Bool,
        detailAvailable: Bool
    ) -> LibraryGameMatchStatus {
        if let rawValue = sanitized(rawValue)?.lowercased(),
           let matchStatus = LibraryGameMatchStatus(rawValue: rawValue) {
            return matchStatus
        }

        if source == .igdb {
            return .confirmed
        }

        if igdbGameID != nil, metadataEnriched {
            return .confirmed
        }

        if igdbGameID != nil {
            return .candidate
        }

        return detailAvailable ? .unmatched : .unknown
    }

    private static func resolvedReleaseYear(from dto: LibraryGameItemDTO) -> Int {
        if let releaseYear = dto.releaseYear, releaseYear > 0 {
            return releaseYear
        }

        guard let releaseDate = dto.releaseDate else { return 0 }
        let date = Date(timeIntervalSince1970: TimeInterval(releaseDate))
        return Calendar.current.component(.year, from: date)
    }

    private static func resolvedIGDBGameID(from dto: LibraryGameItemDTO) -> Int? {
        if let gameId = dto.gameId {
            return gameId
        }

        if let igdbGameId = sanitized(dto.igdbGameId) {
            return Int(igdbGameId)
        }

        return nil
    }

    private static func resolvedGenre(from dto: LibraryGameItemDTO) -> String? {
        sanitized(dto.genreDisplayName)
            ?? sanitized(dto.genre)
            ?? dto.genres?.compactMap(sanitized).first
    }

    private static func resolvedGenreSource(
        from dto: LibraryGameItemDTO,
        source: GameSource,
        igdbGameID: Int?,
        metadataEnriched: Bool,
        hasGenre: Bool
    ) -> LibraryGenreSource? {
        guard hasGenre else { return nil }

        if let rawGenreSource = sanitized(dto.genreSource)?.lowercased(),
           let genreSource = LibraryGenreSource(rawValue: rawGenreSource) {
            return genreSource
        }

        if source == .igdb {
            return .igdb
        }

        if source == .steam, igdbGameID != nil, metadataEnriched {
            return .igdb
        }

        return nil
    }

    private static func resolvedRecentPlaytimeText(from dto: LibraryGameItemDTO) -> String? {
        if let recentPlaytimeText = sanitized(dto.recentPlaytimeText) {
            return recentPlaytimeText
        }

        guard let recentPlaytimeMinutes = dto.recentPlaytimeMinutes else { return nil }
        if recentPlaytimeMinutes < 60 {
            return "\(recentPlaytimeMinutes)분 플레이"
        }

        let hours = recentPlaytimeMinutes / 60
        let minutes = recentPlaytimeMinutes % 60
        if minutes == 0 {
            return "\(hours)시간 플레이"
        }
        return "\(hours)시간 \(minutes)분 플레이"
    }

    private static func resolvedReliableLastPlayedAt(from dto: LibraryGameItemDTO) -> Bool {
        if let explicitValue = dto.hasReliableLastPlayedAt {
            return explicitValue
        }

        guard let normalizedSource = sanitized(dto.lastPlayedAtSource)?.lowercased() else {
            return false
        }

        let trustedSources: Set<String> = [
            "reliable",
            "trusted",
            "play_history",
            "recent_play_history",
            "session_history",
            "activity_event"
        ]
        return trustedSources.contains(normalizedSource)
    }

    private static func defaultPlatform(for source: GameSource) -> String {
        switch source {
        case .steam:
            return "Steam"
        case .igdb:
            return "—"
        }
    }

    private static func defaultDetailAvailability(
        source: GameSource,
        externalGameId: String?,
        igdbGameID: Int?
    ) -> Bool {
        if igdbGameID != nil {
            return true
        }

        if source == .steam, let externalGameId, externalGameId.isEmpty == false {
            return true
        }

        return false
    }

    private static func makeURL(from rawURL: String?) -> URL? {
        guard let rawURL = sanitized(rawURL) else { return nil }
        return URL(string: rawURL)
    }

    private static func igdbCoverURL(from rawURL: String?) -> URL? {
        guard let rawURL = sanitized(rawURL) else { return nil }
        let normalizedURLString = rawURL.hasPrefix("//") ? "https:\(rawURL)" : rawURL
        guard let url = URL(string: normalizedURLString),
              url.host?.lowercased() == "images.igdb.com" else {
            return nil
        }
        return url
    }

    private static func resolvedSteamAppID(
        from dto: LibraryGameItemDTO,
        fallbackSourceID: String?
    ) -> String? {
        if let externalGameId = sanitized(dto.externalGameId), externalGameId.allSatisfy(\.isNumber) {
            return externalGameId
        }

        if let sourceId = sanitized(dto.sourceId), sourceId.allSatisfy(\.isNumber) {
            return sourceId
        }

        if let fallbackSourceID, fallbackSourceID.allSatisfy(\.isNumber) {
            return fallbackSourceID
        }

        if let gameId = dto.gameId {
            return String(gameId)
        }

        return nil
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func parseDate(_ rawValue: String?) -> Date? {
        guard let rawValue = sanitized(rawValue) else { return nil }

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: rawValue) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        return fallbackFormatter.date(from: rawValue)
    }
}
