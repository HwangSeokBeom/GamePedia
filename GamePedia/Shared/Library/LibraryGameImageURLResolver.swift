import Foundation

struct LibraryResolvedImageURLs: Hashable {
    let primaryURL: URL?
    let fallbackURLs: [URL]

    static let empty = LibraryResolvedImageURLs(primaryURL: nil, fallbackURLs: [])
}

enum LibraryGameImageURLResolver {
    private static let igdbImageHosts: Set<String> = ["images.igdb.com"]

    static func resolveBestImageURL(
        gameSource: GameSource,
        externalGameId: String?,
        igdbCoverUrl: URL?
    ) -> URL? {
        resolveImageURLs(
            gameSource: gameSource,
            externalGameId: externalGameId,
            igdbCoverUrl: igdbCoverUrl
        ).primaryURL
    }

    static func resolveImageURLs(
        gameSource: GameSource,
        externalGameId: String?,
        igdbCoverUrl: URL?
    ) -> LibraryResolvedImageURLs {
        switch gameSource {
        case .steam:
            return resolveSteamImageURLs(
                externalGameId: normalizedExternalGameId(externalGameId),
                igdbCoverUrl: sanitizedIGDBCoverURL(igdbCoverUrl)
            )
        case .igdb:
            let sanitizedIGDBCoverUrl = sanitizedIGDBCoverURL(igdbCoverUrl)
            if let sanitizedIGDBCoverUrl {
                logSelectedSource(
                    gameSource: gameSource,
                    externalGameId: normalizedExternalGameId(externalGameId),
                    source: "igdb-cover",
                    url: sanitizedIGDBCoverUrl
                )
                return LibraryResolvedImageURLs(primaryURL: sanitizedIGDBCoverUrl, fallbackURLs: [])
            }

            logFallbackReason(
                gameSource: gameSource,
                externalGameId: normalizedExternalGameId(externalGameId),
                reason: "missing_igdb_cover"
            )
            return .empty
        }
    }

    private static func resolveSteamImageURLs(
        externalGameId: String?,
        igdbCoverUrl: URL?
    ) -> LibraryResolvedImageURLs {
        let candidates = uniqueCandidates(
            from: steamCandidates(
                externalGameId: externalGameId,
                igdbCoverUrl: igdbCoverUrl
            )
        )

        guard let primaryCandidate = candidates.first else {
            let fallbackReason: String
            if igdbCoverUrl == nil, externalGameId == nil {
                fallbackReason = "missing_steam_appid_and_igdb_cover"
            } else if externalGameId == nil {
                fallbackReason = "missing_steam_appid"
            } else {
                fallbackReason = "missing_image_candidates"
            }

            logFallbackReason(
                gameSource: .steam,
                externalGameId: externalGameId,
                reason: fallbackReason
            )
            return .empty
        }

        logSelectedSource(
            gameSource: .steam,
            externalGameId: externalGameId,
            source: primaryCandidate.source,
            url: primaryCandidate.url
        )

        return LibraryResolvedImageURLs(
            primaryURL: primaryCandidate.url,
            fallbackURLs: candidates.dropFirst().map(\.url)
        )
    }

    private static func steamCandidates(
        externalGameId: String?,
        igdbCoverUrl: URL?
    ) -> [LibraryResolvedImageCandidate] {
        var candidates: [LibraryResolvedImageCandidate] = []

        if let igdbCoverUrl {
            candidates.append(
                LibraryResolvedImageCandidate(
                    source: "igdb-cover",
                    url: igdbCoverUrl
                )
            )
        }

        guard let externalGameId else {
            return candidates
        }

        candidates.append(
            contentsOf: [
                LibraryResolvedImageCandidate(
                    source: "steam-header-cdn",
                    url: steamHeaderCDNURL(appID: externalGameId)
                ),
                LibraryResolvedImageCandidate(
                    source: "steam-header",
                    url: steamHeaderSharedURL(appID: externalGameId)
                ),
                LibraryResolvedImageCandidate(
                    source: "steam-library-600x900-2x",
                    url: steamLibrary600x9002xURL(appID: externalGameId)
                ),
                LibraryResolvedImageCandidate(
                    source: "steam-library-600x900",
                    url: steamLibrary600x900URL(appID: externalGameId)
                ),
                LibraryResolvedImageCandidate(
                    source: "steam-library-capsule",
                    url: steamLibraryCapsuleURL(appID: externalGameId)
                ),
                LibraryResolvedImageCandidate(
                    source: "steam-capsule",
                    url: steamCapsuleURL(appID: externalGameId)
                )
            ]
        )

        return candidates
    }

    private static func uniqueCandidates(
        from candidates: [LibraryResolvedImageCandidate]
    ) -> [LibraryResolvedImageCandidate] {
        var seenURLs = Set<String>()
        return candidates.filter { candidate in
            seenURLs.insert(candidate.url.absoluteString).inserted
        }
    }

    private static func sanitizedIGDBCoverURL(_ url: URL?) -> URL? {
        guard let url else { return nil }

        let absoluteString = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !absoluteString.isEmpty else { return nil }

        let normalizedString = absoluteString.hasPrefix("//")
            ? "https:\(absoluteString)"
            : absoluteString

        guard let normalizedURL = URL(string: normalizedString),
              let host = normalizedURL.host?.lowercased(),
              igdbImageHosts.contains(host) else {
            return nil
        }

        return normalizedURL
    }

    private static func normalizedExternalGameId(_ externalGameId: String?) -> String? {
        guard let externalGameId else { return nil }

        let normalizedValue = externalGameId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else { return nil }
        guard normalizedValue.allSatisfy(\.isNumber) else { return nil }
        return normalizedValue
    }

    private static func steamHeaderCDNURL(appID: String) -> URL {
        URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/header.jpg")!
    }

    private static func steamHeaderSharedURL(appID: String) -> URL {
        URL(string: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(appID)/header.jpg")!
    }

    private static func steamLibrary600x9002xURL(appID: String) -> URL {
        URL(string: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(appID)/library_600x900_2x.jpg")!
    }

    private static func steamLibrary600x900URL(appID: String) -> URL {
        URL(string: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(appID)/library_600x900.jpg")!
    }

    private static func steamLibraryCapsuleURL(appID: String) -> URL {
        URL(string: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(appID)/library_capsule.jpg")!
    }

    private static func steamCapsuleURL(appID: String) -> URL {
        URL(string: "https://shared.cloudflare.steamstatic.com/store_item_assets/steam/apps/\(appID)/capsule_616x353.jpg")!
    }

    private static func logSelectedSource(
        gameSource: GameSource,
        externalGameId: String?,
        source: String,
        url: URL
    ) {
        print(
            "[GameImageResolver] " +
            "sourceSelected=\(source) " +
            "gameSource=\(gameSource.rawValue) " +
            "externalGameId=\(externalGameId ?? "nil") " +
            "imageURLGenerated=\(url.absoluteString)"
        )
    }

    private static func logFallbackReason(
        gameSource: GameSource,
        externalGameId: String?,
        reason: String
    ) {
        print(
            "[GameImageResolver] " +
            "sourceSelected=placeholder " +
            "gameSource=\(gameSource.rawValue) " +
            "externalGameId=\(externalGameId ?? "nil") " +
            "fallbackReason=\(reason)"
        )
    }
}

private struct LibraryResolvedImageCandidate: Hashable {
    let source: String
    let url: URL
}
