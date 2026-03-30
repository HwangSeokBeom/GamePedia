import Foundation

struct LibraryCachedState {
    let isSteamConnected: Bool
    let isSteamSyncAvailable: Bool
    let steamSyncErrorCode: String?
    let recentlyPlayed: [LibraryGameSummary]
    let playingGames: [LibraryGameSummary]
    let ownedGames: [LibraryGameSummary]
    let backlogGames: [LibraryGameSummary]
    let sections: [LibrarySectionViewState]
}

final class LibraryCacheStore {
    static let shared = LibraryCacheStore()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cacheKey = "gamepedia.library.cached_state.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> LibraryCachedState? {
        guard let data = userDefaults.data(forKey: cacheKey),
              let storedState = try? decoder.decode(StoredLibraryCachedState.self, from: data) else {
            return nil
        }

        return LibraryCachedState(
            isSteamConnected: storedState.isSteamConnected,
            isSteamSyncAvailable: storedState.isSteamSyncAvailable,
            steamSyncErrorCode: storedState.steamSyncErrorCode,
            recentlyPlayed: storedState.recentlyPlayed.map(\.libraryGameSummary),
            playingGames: storedState.playingGames.map(\.libraryGameSummary),
            ownedGames: storedState.ownedGames.map(\.libraryGameSummary),
            backlogGames: storedState.backlogGames.map(\.libraryGameSummary),
            sections: storedState.sections.compactMap(\.sectionViewState)
        )
    }

    func save(
        isSteamConnected: Bool,
        isSteamSyncAvailable: Bool,
        steamSyncErrorCode: String?,
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        ownedGames: [LibraryGameSummary],
        backlogGames: [LibraryGameSummary],
        sections: [LibrarySectionViewState]
    ) {
        let storedState = StoredLibraryCachedState(
            isSteamConnected: isSteamConnected,
            isSteamSyncAvailable: isSteamSyncAvailable,
            steamSyncErrorCode: steamSyncErrorCode,
            recentlyPlayed: recentlyPlayed.map(StoredLibraryGameSummary.init),
            playingGames: playingGames.map(StoredLibraryGameSummary.init),
            ownedGames: ownedGames.map(StoredLibraryGameSummary.init),
            backlogGames: backlogGames.map(StoredLibraryGameSummary.init),
            sections: sections.map(StoredLibrarySection.init)
        )

        guard let data = try? encoder.encode(storedState) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: cacheKey)
    }
}

private struct StoredLibraryCachedState: Codable {
    let isSteamConnected: Bool
    let isSteamSyncAvailable: Bool
    let steamSyncErrorCode: String?
    let recentlyPlayed: [StoredLibraryGameSummary]
    let playingGames: [StoredLibraryGameSummary]
    let ownedGames: [StoredLibraryGameSummary]
    let backlogGames: [StoredLibraryGameSummary]
    let sections: [StoredLibrarySection]
}

private struct StoredLibraryGameSummary: Codable {
    let source: String
    let sourceID: String
    let canonicalGameID: Int?
    let title: String
    let translatedTitle: String?
    let coverImageURL: URL?
    let fallbackCoverImageURLs: [URL]
    let genre: String
    let platform: String
    let releaseYear: Int
    let rating: Double?
    let recentPlaytimeMinutes: Int?
    let recentPlaytimeText: String?
    let userStatus: String?
    let metadataEnriched: Bool
    let detailAvailable: Bool
    let matchStatus: String

    init(_ summary: LibraryGameSummary) {
        source = summary.identifier.source.rawValue
        sourceID = summary.identifier.sourceID
        canonicalGameID = summary.identifier.canonicalGameID
        title = summary.title
        translatedTitle = summary.translatedTitle
        coverImageURL = summary.coverImageURL
        fallbackCoverImageURLs = summary.fallbackCoverImageURLs
        genre = summary.genre
        platform = summary.platform
        releaseYear = summary.releaseYear
        rating = summary.rating
        recentPlaytimeMinutes = summary.recentPlaytimeMinutes
        recentPlaytimeText = summary.recentPlaytimeText
        userStatus = summary.userStatus?.rawValue
        metadataEnriched = summary.metadataEnriched
        detailAvailable = summary.detailAvailable
        matchStatus = summary.matchStatus.rawValue
    }

    var libraryGameSummary: LibraryGameSummary {
        LibraryGameSummary(
            identifier: LibraryGameIdentifier(
                source: GameSource(rawValue: source) ?? .igdb,
                sourceID: sourceID,
                canonicalGameID: canonicalGameID
            ),
            title: title,
            translatedTitle: translatedTitle,
            coverImageURL: coverImageURL,
            fallbackCoverImageURLs: fallbackCoverImageURLs,
            genre: genre,
            platform: platform,
            releaseYear: releaseYear,
            rating: rating,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            recentPlaytimeText: recentPlaytimeText,
            userStatus: userStatus.flatMap(UserGameStatus.init(rawValue:)),
            metadataEnriched: metadataEnriched,
            detailAvailable: detailAvailable,
            matchStatus: LibraryGameMatchStatus(rawValue: matchStatus) ?? .unknown
        )
    }
}

private struct StoredLibrarySection: Codable {
    let kind: Int
    let layoutStyle: String
    let showsSeeAll: Bool
    let items: [StoredLibraryCollectionItem]

    init(_ section: LibrarySectionViewState) {
        kind = section.kind.rawValue
        layoutStyle = section.layoutStyle.storedValue
        showsSeeAll = section.showsSeeAll
        items = section.items.map(StoredLibraryCollectionItem.init)
    }

    var sectionViewState: LibrarySectionViewState? {
        guard let sectionKind = LibrarySectionKind(rawValue: kind),
              let layoutStyle = LibrarySectionLayoutStyle(storedValue: layoutStyle) else {
            return nil
        }

        return LibrarySectionViewState(
            kind: sectionKind,
            layoutStyle: layoutStyle,
            items: items.compactMap(\.collectionItem),
            showsSeeAll: showsSeeAll
        )
    }
}

private struct StoredLibraryCollectionItem: Codable {
    let type: String
    let recentCard: StoredRecentCardViewState?
    let row: StoredRowViewState?
    let message: StoredMessageViewState?

    init(_ item: LibraryCollectionItem) {
        switch item {
        case .recentCard(let viewState):
            type = "recentCard"
            recentCard = StoredRecentCardViewState(viewState)
            row = nil
            message = nil
        case .row(let viewState):
            type = "row"
            recentCard = nil
            row = StoredRowViewState(viewState)
            message = nil
        case .message(let viewState):
            type = "message"
            recentCard = nil
            row = nil
            message = StoredMessageViewState(viewState)
        }
    }

    var collectionItem: LibraryCollectionItem? {
        switch type {
        case "recentCard":
            return recentCard.map(\.collectionItem)
        case "row":
            return row.map(\.collectionItem)
        case "message":
            return message.map(\.collectionItem)
        default:
            return nil
        }
    }
}

private struct StoredRecentCardViewState: Codable {
    let source: String
    let sourceID: String
    let canonicalGameID: Int?
    let title: String
    let metadataText: String
    let ratingText: String?
    let coverImageURL: URL?
    let fallbackCoverImageURLs: [URL]
    let badgeText: String
    let actionTitle: String?
    let isActionEnabled: Bool

    init(_ viewState: LibraryRecentGameCardViewState) {
        source = viewState.identifier.source.rawValue
        sourceID = viewState.identifier.sourceID
        canonicalGameID = viewState.identifier.canonicalGameID
        title = viewState.title
        metadataText = viewState.metadataText
        ratingText = viewState.ratingText
        coverImageURL = viewState.coverImageURL
        fallbackCoverImageURLs = viewState.fallbackCoverImageURLs
        badgeText = viewState.badgeText
        actionTitle = viewState.actionTitle
        isActionEnabled = viewState.isActionEnabled
    }

    var collectionItem: LibraryCollectionItem {
        .recentCard(
            LibraryRecentGameCardViewState(
                identifier: LibraryGameIdentifier(
                    source: GameSource(rawValue: source) ?? .igdb,
                    sourceID: sourceID,
                    canonicalGameID: canonicalGameID
                ),
                detailDestination: nil,
                title: title,
                metadataText: metadataText,
                ratingText: ratingText,
                coverImageURL: coverImageURL,
                fallbackCoverImageURLs: fallbackCoverImageURLs,
                badgeText: badgeText,
                actionTitle: actionTitle,
                isActionEnabled: isActionEnabled
            )
        )
    }
}

private struct StoredRowViewState: Codable {
    let source: String
    let sourceID: String
    let canonicalGameID: Int?
    let title: String
    let subtitleText: String
    let metadataText: String
    let coverImageURL: URL?
    let fallbackCoverImageURLs: [URL]
    let ratingText: String?
    let trailingAction: String?

    init(_ viewState: LibraryGameRowViewState) {
        source = viewState.identifier.source.rawValue
        sourceID = viewState.identifier.sourceID
        canonicalGameID = viewState.identifier.canonicalGameID
        title = viewState.title
        subtitleText = viewState.subtitleText
        metadataText = viewState.metadataText
        coverImageURL = viewState.coverImageURL
        fallbackCoverImageURLs = viewState.fallbackCoverImageURLs
        ratingText = viewState.ratingText
        trailingAction = viewState.trailingAction?.storedValue
    }

    var collectionItem: LibraryCollectionItem {
        .row(
            LibraryGameRowViewState(
                identifier: LibraryGameIdentifier(
                    source: GameSource(rawValue: source) ?? .igdb,
                    sourceID: sourceID,
                    canonicalGameID: canonicalGameID
                ),
                detailDestination: nil,
                title: title,
                subtitleText: subtitleText,
                metadataText: metadataText,
                coverImageURL: coverImageURL,
                fallbackCoverImageURLs: fallbackCoverImageURLs,
                ratingText: ratingText,
                trailingAction: trailingAction.flatMap(LibraryRowTrailingAction.init(storedValue:))
            )
        )
    }
}

private struct StoredMessageViewState: Codable {
    let id: String
    let style: String
    let title: String?
    let message: String
    let detailText: String?
    let buttonTitle: String?
    let action: String?

    init(_ viewState: LibraryMessageViewState) {
        id = viewState.id
        style = viewState.style.storedValue
        title = viewState.title
        message = viewState.message
        detailText = viewState.detailText
        buttonTitle = viewState.buttonTitle
        action = viewState.action?.storedValue
    }

    var collectionItem: LibraryCollectionItem {
        .message(
            LibraryMessageViewState(
                id: id,
                style: LibraryMessageStyle(storedValue: style) ?? .empty,
                title: title,
                message: message,
                detailText: detailText,
                buttonTitle: buttonTitle,
                action: action.flatMap(LibraryMessageAction.init(storedValue:))
            )
        )
    }
}

private extension LibrarySectionLayoutStyle {
    var storedValue: String {
        switch self {
        case .recentCards:
            return "recentCards"
        case .list:
            return "list"
        case .message:
            return "message"
        }
    }

    init?(storedValue: String) {
        switch storedValue {
        case "recentCards":
            self = .recentCards
        case "list":
            self = .list
        case "message":
            self = .message
        default:
            return nil
        }
    }
}

private extension LibraryRowTrailingAction {
    var storedValue: String {
        switch self {
        case .removeWishlist:
            return "removeWishlist"
        }
    }

    init?(storedValue: String) {
        switch storedValue {
        case "removeWishlist":
            self = .removeWishlist
        default:
            return nil
        }
    }
}

private extension LibraryMessageStyle {
    var storedValue: String {
        switch self {
        case .banner:
            return "banner"
        case .empty:
            return "empty"
        case .error:
            return "error"
        case .loading:
            return "loading"
        }
    }

    init?(storedValue: String) {
        switch storedValue {
        case "banner":
            self = .banner
        case "empty":
            self = .empty
        case "error":
            self = .error
        case "loading":
            self = .loading
        default:
            return nil
        }
    }
}

private extension LibraryMessageAction {
    var storedValue: String {
        switch self {
        case .connectSteam:
            return "connectSteam"
        case .showSteamPrivacyGuide:
            return "showSteamPrivacyGuide"
        case .retrySteamSync:
            return "retrySteamSync"
        }
    }

    init?(storedValue: String) {
        switch storedValue {
        case "connectSteam":
            self = .connectSteam
        case "showSteamPrivacyGuide":
            self = .showSteamPrivacyGuide
        case "retrySteamSync":
            self = .retrySteamSync
        default:
            return nil
        }
    }
}
