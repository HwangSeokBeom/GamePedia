import Foundation

struct LibraryCachedState {
    let isSteamConnected: Bool
    let steamSyncStatus: SteamSyncStatus
    let isSteamSyncAvailable: Bool
    let steamSyncErrorCode: String?
    let recentlyPlayed: [LibraryGameSummary]
    let playingGames: [LibraryGameSummary]
    let ownedGames: [LibraryGameSummary]
    let backlogGames: [LibraryGameSummary]
    let playtimeRecommendations: [PlaytimeRecommendation]
    let friendRecommendations: [SteamFriendRecommendation]
    let friendRecommendationsSource: LibraryFriendRecommendationSource
    let friendRecommendationsEmptyState: LibraryFriendRecommendationsEmptyState?
    let sections: [LibrarySectionViewState]
}

final class LibraryCacheStore {
    static let shared = LibraryCacheStore()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cacheKey = "gamepedia.library.cached_state.v5"
    private let steamConnectionOnboardingKey = "gamepedia.library.steam_connection_onboarding_shown.v1"
    private let lastSuccessfulSteamSyncDateKey = "gamepedia.library.last_successful_steam_sync_date.v1"
    private let lastAttemptedSteamSyncDateKey = "gamepedia.library.last_attempted_steam_sync_date.v1"

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
            steamSyncStatus: SteamSyncStatus(rawValue: storedState.steamSyncStatus) ?? .idle,
            isSteamSyncAvailable: storedState.isSteamSyncAvailable,
            steamSyncErrorCode: storedState.steamSyncErrorCode,
            recentlyPlayed: storedState.recentlyPlayed.map(\.libraryGameSummary),
            playingGames: storedState.playingGames.map(\.libraryGameSummary),
            ownedGames: storedState.ownedGames.map(\.libraryGameSummary),
            backlogGames: storedState.backlogGames.map(\.libraryGameSummary),
            playtimeRecommendations: storedState.playtimeRecommendations.map(\.recommendation),
            friendRecommendations: storedState.friendRecommendations.map(\.recommendation),
            friendRecommendationsSource: LibraryFriendRecommendationSource(rawValue: storedState.friendRecommendationsSource) ?? .none,
            friendRecommendationsEmptyState: storedState.friendRecommendationsEmptyState.flatMap(LibraryFriendRecommendationsEmptyState.init(rawValue:)),
            sections: storedState.sections.compactMap(\.sectionViewState)
        )
    }

    func save(
        isSteamConnected: Bool,
        steamSyncStatus: SteamSyncStatus,
        isSteamSyncAvailable: Bool,
        steamSyncErrorCode: String?,
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        ownedGames: [LibraryGameSummary],
        backlogGames: [LibraryGameSummary],
        playtimeRecommendations: [PlaytimeRecommendation],
        friendRecommendations: [SteamFriendRecommendation],
        friendRecommendationsSource: LibraryFriendRecommendationSource,
        friendRecommendationsEmptyState: LibraryFriendRecommendationsEmptyState?,
        sections: [LibrarySectionViewState]
    ) {
        let storedState = StoredLibraryCachedState(
            isSteamConnected: isSteamConnected,
            steamSyncStatus: steamSyncStatus.rawValue,
            isSteamSyncAvailable: isSteamSyncAvailable,
            steamSyncErrorCode: steamSyncErrorCode,
            recentlyPlayed: recentlyPlayed.map(StoredLibraryGameSummary.init),
            playingGames: playingGames.map(StoredLibraryGameSummary.init),
            ownedGames: ownedGames.map(StoredLibraryGameSummary.init),
            backlogGames: backlogGames.map(StoredLibraryGameSummary.init),
            playtimeRecommendations: playtimeRecommendations.map(StoredPlaytimeRecommendation.init),
            friendRecommendations: friendRecommendations.map(StoredSteamFriendRecommendation.init),
            friendRecommendationsSource: friendRecommendationsSource.rawValue,
            friendRecommendationsEmptyState: friendRecommendationsEmptyState?.rawValue,
            sections: sections.map(StoredLibrarySection.init)
        )

        guard let data = try? encoder.encode(storedState) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: cacheKey)
    }

    func loadLastSuccessfulSteamSyncDate() -> Date? {
        userDefaults.object(forKey: lastSuccessfulSteamSyncDateKey) as? Date
    }

    func saveLastSuccessfulSteamSyncDate(_ date: Date) {
        userDefaults.set(date, forKey: lastSuccessfulSteamSyncDateKey)
    }

    func loadLastAttemptedSteamSyncDate() -> Date? {
        userDefaults.object(forKey: lastAttemptedSteamSyncDateKey) as? Date
    }

    func saveLastAttemptedSteamSyncDate(_ date: Date) {
        userDefaults.set(date, forKey: lastAttemptedSteamSyncDateKey)
    }

    func clearSteamSyncDates() {
        userDefaults.removeObject(forKey: lastSuccessfulSteamSyncDateKey)
        userDefaults.removeObject(forKey: lastAttemptedSteamSyncDateKey)
    }

    func hasShownSteamConnectionOnboarding() -> Bool {
        userDefaults.bool(forKey: steamConnectionOnboardingKey)
    }

    func markSteamConnectionOnboardingShown() {
        userDefaults.set(true, forKey: steamConnectionOnboardingKey)
    }
}

private struct StoredLibraryCachedState: Codable {
    let isSteamConnected: Bool
    let steamSyncStatus: String
    let isSteamSyncAvailable: Bool
    let steamSyncErrorCode: String?
    let recentlyPlayed: [StoredLibraryGameSummary]
    let playingGames: [StoredLibraryGameSummary]
    let ownedGames: [StoredLibraryGameSummary]
    let backlogGames: [StoredLibraryGameSummary]
    let playtimeRecommendations: [StoredPlaytimeRecommendation]
    let friendRecommendations: [StoredSteamFriendRecommendation]
    let friendRecommendationsSource: String
    let friendRecommendationsEmptyState: String?
    let sections: [StoredLibrarySection]
}

private struct StoredPlaytimeRecommendation: Codable {
    let game: StoredLibraryGameSummary
    let reason: String?

    init(_ recommendation: PlaytimeRecommendation) {
        game = StoredLibraryGameSummary(recommendation.game)
        reason = recommendation.reason
    }

    var recommendation: PlaytimeRecommendation {
        PlaytimeRecommendation(
            game: game.libraryGameSummary,
            reason: reason
        )
    }
}

private struct StoredSteamFriendRecommendation: Codable {
    let game: StoredLibraryGameSummary
    let friendCount: Int
    let reason: String?

    init(_ recommendation: SteamFriendRecommendation) {
        game = StoredLibraryGameSummary(recommendation.game)
        friendCount = recommendation.friendCount
        reason = recommendation.reason
    }

    var recommendation: SteamFriendRecommendation {
        SteamFriendRecommendation(
            game: game.libraryGameSummary,
            friendCount: friendCount,
            reason: reason
        )
    }
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
    let genreSource: String?
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
    let userStatus: String?
    let enrichmentStatus: String?
    let metadataEnriched: Bool
    let detailAvailable: Bool
    let matchStatus: String

    init(_ summary: LibraryGameSummary) {
        source = summary.identifier.source.rawValue
        sourceID = summary.identifier.sourceID
        canonicalGameID = summary.identifier.canonicalGameID
        title = summary.title
        translatedTitle = nil
        coverImageURL = summary.coverImageURL
        fallbackCoverImageURLs = summary.fallbackCoverImageURLs
        genre = summary.genre
        genreSource = summary.genreSource?.rawValue
        platform = summary.platform
        releaseYear = summary.releaseYear
        rating = summary.rating
        recentPlaytimeMinutes = summary.recentPlaytimeMinutes
        recentPlaytimeText = summary.recentPlaytimeText
        lastPlayedAt = summary.lastPlayedAt
        lastPlayedAtSource = summary.lastPlayedAtSource
        hasReliableLastPlayedAt = summary.hasReliableLastPlayedAt
        recentPlayFallbackReason = summary.recentPlayFallbackReason
        playtimeMinutes = summary.playtimeMinutes
        userStatus = summary.userStatus?.rawValue
        enrichmentStatus = summary.enrichmentStatus.rawValue
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
            translatedTitle: nil,
            coverImageURL: coverImageURL,
            fallbackCoverImageURLs: fallbackCoverImageURLs,
            genre: genre,
            genreSource: genreSource.flatMap(LibraryGenreSource.init(rawValue:)),
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
            userStatus: userStatus.flatMap(UserGameStatus.init(rawValue:)),
            enrichmentStatus: enrichmentStatus
                .flatMap(LibraryGameEnrichmentStatus.init(rawValue:)) ?? .unknown,
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
        case .retryOwnedSteamSync:
            return "retryOwnedSteamSync"
        case .retryPlaytimeRecommendations:
            return "retryPlaytimeRecommendations"
        case .retryFriendRecommendations:
            return "retryFriendRecommendations"
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
        case "retryOwnedSteamSync":
            self = .retryOwnedSteamSync
        case "retryPlaytimeRecommendations":
            self = .retryPlaytimeRecommendations
        case "retryFriendRecommendations":
            self = .retryFriendRecommendations
        default:
            return nil
        }
    }
}
