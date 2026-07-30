import Foundation

// MARK: - TodaySectionKey

/// The eight Today sections, in the order the server composes them. The app
/// still renders in `meta.sectionOrder`; this ordering exists only so a
/// section the server omitted has a stable place if the app ever needs one.
enum TodaySectionKey: String, CaseIterable, Sendable {
    case playCompass
    case gameDNA
    case gameBriefing
    case backlogRescue
    case spoilerFreeStartGuide
    case editorialCuration
    case monthlyReplay
    case friendActivity
}

// MARK: - TodayFeed

struct TodayFeed: Equatable, Sendable {
    let generatedAt: Date
    /// The IANA zone the server resolved the feed in. Rendered as given; the
    /// client never recomputes a boundary from it.
    let timezone: String
    let locale: String?
    /// Already ordered by `meta.sectionOrder`.
    let sections: [TodaySection]
    /// True when at least one section failed. It describes *sections*, not the
    /// feed: a feed with `partialFailure` is a successful feed with a hole in
    /// it, and is never rendered as an error.
    let partialFailure: Bool

    var okSectionCount: Int {
        sections.filter { if case .content = $0.state { return true } else { return false } }.count
    }

    /// Sections the user can ask to retry individually.
    var retryableKeys: [TodaySectionKey] {
        sections.compactMap { section in
            if case .unavailable = section.state { return section.key }
            return nil
        }
    }
}

// MARK: - TodaySection

struct TodaySection: Equatable, Sendable, Identifiable {
    let key: TodaySectionKey
    let state: State

    var id: TodaySectionKey { key }

    enum State: Equatable, Sendable {
        case content(Content)
        /// The feature's kill switch is off. Presented as an explanation or
        /// hidden entirely — never as an error, and never as a button that
        /// cannot work.
        case disabled(reasonCode: String)
        /// The section failed to compute. The user gets a retry for this
        /// section alone; the rest of the feed is untouched.
        case unavailable(reasonCode: String)
    }

    enum Content: Equatable, Sendable {
        case playCompass(TodayPlayCompassSummary)
        case gameDNA(TodayGameDNASummary)
        case gameBriefing(items: [TodayBriefingItem], emptyReason: String?)
        case backlogRescue(items: [TodayBacklogItem], emptyReason: String?)
        case spoilerFreeStartGuide(items: [TodayStartGuideItem], emptyReason: String?)
        case editorialCuration(articles: [ArticleCard], emptyReason: String?)
        case monthlyReplay(TodayReplaySummary)
        case friendActivity(items: [TodayFriendActivityItem], emptyReason: String?)
    }
}

// MARK: - Section payloads

struct TodayPlayCompassSummary: Equatable, Sendable {
    let recommendations: [PlayCompassRecommendation]
    let confidence: PlayIntelligenceConfidence
    let freshness: PlayCompassFreshness
    let emptyReason: PlayCompassEmptyReason?
    /// The contract pins this to true. Surfaced so the UI can state the
    /// guarantee to the user rather than implying it.
    let ownedOnly: Bool
}

struct TodayGameDNASummary: Equatable, Sendable {
    let signalCount: Int
    let confidence: PlayIntelligenceConfidence
    let generatedAt: Date
    let topGenres: [GameDNAGenreWeight]
    let sessionLength: GameDNASessionLength
    let social: GameDNASocialLeaning
    let tone: GameDNATone
    let missingSignals: [String]
    let reasonCodes: [String]
}

struct TodayBriefingItem: Equatable, Sendable {
    let catalogGameID: CatalogGameID
    let title: String
    let updatedAt: Date
    let noteworthyReleases: [NoteworthyRelease]

    struct NoteworthyRelease: Equatable, Sendable {
        let countryCode: String
        let platform: String
        let serviceStatus: CatalogServiceStatus
        let shutdownDate: String?
        let provenance: CatalogProvenance
    }
}

struct TodayBacklogItem: Equatable, Sendable {
    let catalogGameID: CatalogGameID
    let title: String
    let addedAt: Date
    let ownershipProvenance: CatalogProvenance
}

struct TodayStartGuideItem: Equatable, Sendable {
    let catalogGameID: CatalogGameID
    let title: String
    let libraryStatus: OwnedLibraryStatus
    let genres: [String]
    let platforms: [String]
    let estimatedFirstSessionMinutes: Int?
    let soloFriendly: Bool?
    let partyFriendly: Bool?
}

struct TodayReplaySummary: Equatable, Sendable {
    let monthKey: String
    let timezone: String
    let isEmpty: Bool
    let playedDayCount: Int
    let totalMinutes: Int
    let mostPlayedGame: Highlight?
    let surpriseGame: Highlight?
    let missingData: [MonthlyReplayGap]

    struct Highlight: Equatable, Sendable {
        let catalogGameID: CatalogGameID
        let title: String?
        let totalMinutes: Int
        let sessionCount: Int
        /// False when some sessions had no recorded duration, so the total is
        /// a floor rather than a fact.
        let minutesKnown: Bool
    }
}

struct TodayFriendActivityItem: Equatable, Sendable {
    enum Kind: String, Sendable {
        case reviewCreated = "REVIEW_CREATED"
        case reviewUpdated = "REVIEW_UPDATED"
        case likedGameAdded = "LIKED_GAME_ADDED"
        case likedGameRemoved = "LIKED_GAME_REMOVED"
        case ratingChanged = "RATING_CHANGED"
        case playStatusChanged = "PLAY_STATUS_CHANGED"
        case steamRecentlyPlayedSync = "STEAM_RECENTLY_PLAYED_SYNC"
    }

    let activityID: UUID
    let actorUserID: UUID
    let kind: Kind
    /// Nil for activities the server could not attach to a canonical game.
    let catalogGameID: CatalogGameID?
    /// The only server-supplied bridge to the legacy IGDB identifier space.
    let legacyIdentity: LegacyGameIdentity
    let createdAt: Date
}

// MARK: - Shared value types

enum PlayIntelligenceConfidence: String, Equatable, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

enum OwnedLibraryStatus: String, Equatable, Sendable {
    case playing = "PLAYING"
    case backlog = "BACKLOG"
}

enum GameDNASessionLength: String, Equatable, Sendable {
    case unknown = "UNKNOWN"
    case short = "SHORT"
    case mixed = "MIXED"
    case long = "LONG"
}

enum GameDNASocialLeaning: String, Equatable, Sendable {
    case multiplayer = "MULTIPLAYER"
    case singleplayer = "SINGLEPLAYER"
    case balanced = "BALANCED"
}

enum GameDNATone: String, Equatable, Sendable {
    case comfort = "COMFORT"
    case challenge = "CHALLENGE"
    case balanced = "BALANCED"
}

struct GameDNAGenreWeight: Equatable, Sendable {
    let genre: String
    let weight: Int
    /// 0...1 of the profile this genre accounts for.
    let share: Double
}

struct MonthlyReplayGap: Equatable, Sendable {
    let code: String
    let affectedSessionCount: Int?
    let affectedGameCount: Int?
    let effect: String
}
