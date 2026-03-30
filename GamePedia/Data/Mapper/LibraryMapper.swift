import Foundation

enum LibraryMapper {

    static func toSteamLinkStatus(_ dto: SteamLinkStatusDTO?) -> SteamLinkStatus {
        guard let dto else { return .notLinked }

        return SteamLinkStatus(
            connectionState: dto.isLinked ? .linked : .notLinked,
            steamID: sanitized(dto.steamId),
            displayName: sanitized(dto.displayName),
            profileURL: makeURL(from: dto.profileUrl)
        )
    }

    static func toGameSummary(_ dto: LibraryGameItemDTO) throws -> LibraryGameSummary {
        let source = resolvedSource(from: dto.source)
        let canonicalGameID = dto.gameId
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
        let genre = sanitized(dto.genre) ?? dto.genres?.first ?? "기타"
        let platform = sanitized(dto.platform) ?? dto.platforms?.first ?? defaultPlatform(for: source)
        let releaseYear = resolvedReleaseYear(from: dto)
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

        return LibraryGameSummary(
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
            platform: platform,
            releaseYear: releaseYear,
            rating: normalizedRating(from: dto),
            recentPlaytimeMinutes: dto.recentPlaytimeMinutes,
            recentPlaytimeText: resolvedRecentPlaytimeText(from: dto),
            userStatus: resolvedStatus(from: dto.userStatus ?? dto.status)
        )
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
            ?? sanitized(dto.title)
            ?? sanitized(dto.name)
            ?? "이름 없는 게임"
    }

    private static func resolvedTranslatedTitle(from dto: LibraryGameItemDTO, fallbackTitle: String) -> String? {
        let candidate = sanitized(dto.translatedTitle)
            ?? sanitized(dto.title)
            ?? sanitized(dto.name)
        guard let candidate, candidate != fallbackTitle else { return nil }
        return candidate
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

    private static func resolvedReleaseYear(from dto: LibraryGameItemDTO) -> Int {
        if let releaseYear = dto.releaseYear, releaseYear > 0 {
            return releaseYear
        }

        guard let releaseDate = dto.releaseDate else { return 0 }
        let date = Date(timeIntervalSince1970: TimeInterval(releaseDate))
        return Calendar.current.component(.year, from: date)
    }

    private static func normalizedRating(from dto: LibraryGameItemDTO) -> Double? {
        let rawRating = dto.totalRating ?? dto.aggregatedRating ?? dto.rating
        guard let rawRating else { return nil }
        return rawRating > 5 ? rawRating / 20.0 : rawRating
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

    private static func defaultPlatform(for source: GameSource) -> String {
        switch source {
        case .steam:
            return "Steam"
        case .igdb:
            return "—"
        }
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
}
