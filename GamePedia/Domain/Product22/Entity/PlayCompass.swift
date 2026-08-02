import Foundation

// MARK: - PlayCompassRequest

/// What the user asked for. Every field is constrained to what the contract
/// accepts, so a request that the server would reject cannot be constructed.
struct PlayCompassQuery: Equatable, Sendable {

    /// Contract bounds: 5...1440.
    static let minimumMinutes = 5
    static let maximumMinutes = 1440
    /// The quick choices the UI offers. Any value in range is still allowed
    /// through the detail picker.
    static let quickChoices = [30, 60, 90]

    var availableMinutes: Int
    var mood: PlaySessionMood?
    var energy: PlayCompassEnergy?
    var soloOrParty: PlayCompassCompany?
    var continueOrStart: PlayCompassContinuity?
    /// Contract caps this at 12 entries.
    var availablePlatforms: [String]
    /// Contract caps this at 20 entries.
    var friendUserIDs: [UUID]

    init(
        availableMinutes: Int = 60,
        mood: PlaySessionMood? = nil,
        energy: PlayCompassEnergy? = nil,
        soloOrParty: PlayCompassCompany? = nil,
        continueOrStart: PlayCompassContinuity? = nil,
        availablePlatforms: [String] = [],
        friendUserIDs: [UUID] = []
    ) {
        self.availableMinutes = min(max(availableMinutes, Self.minimumMinutes), Self.maximumMinutes)
        self.mood = mood
        self.energy = energy
        self.soloOrParty = soloOrParty
        self.continueOrStart = continueOrStart
        self.availablePlatforms = Array(availablePlatforms.prefix(12))
        self.friendUserIDs = Array(friendUserIDs.prefix(20))
    }
}

enum PlayCompassEnergy: String, CaseIterable, Equatable, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
}

enum PlayCompassCompany: String, CaseIterable, Equatable, Sendable {
    case solo = "SOLO"
    case party = "PARTY"
    case either = "EITHER"
}

enum PlayCompassContinuity: String, CaseIterable, Equatable, Sendable {
    case resume = "CONTINUE"
    case start = "START"
    case either = "EITHER"
}

// MARK: - PlayCompassResult

struct PlayCompassResult: Equatable, Sendable {
    /// At most three, drawn only from owned PLAYING/BACKLOG library entries.
    let recommendations: [PlayCompassRecommendation]
    let confidence: PlayIntelligenceConfidence
    let generatedAt: Date
    let freshness: PlayCompassFreshness
    let emptyReason: PlayCompassEmptyReason?
    let ownedOnly: Bool
    /// Identifies the recommendation round. Feedback must carry the same hash
    /// so the server can attribute it to the request it came from.
    let requestHash: String
}

struct PlayCompassFreshness: Equatable, Sendable {
    let candidatePoolSize: Int
    let freshestLibraryUpdateAt: Date?
    let playlogSampleSize: Int
    /// True when the underlying library/playlog data is behind. Shown to the
    /// user as an explanation, not as a failure.
    let isStale: Bool
}

enum PlayCompassEmptyReason: String, Equatable, Sendable {
    case noOwnedPlayingOrBacklogGames = "no_owned_playing_or_backlog_games"
    case noCandidateMatchedConstraints = "no_candidate_matched_constraints"
}

// MARK: - PlayCompassRecommendation

struct PlayCompassRecommendation: Equatable, Sendable {
    let catalogGameID: CatalogGameID
    let title: String?
    /// 1...3.
    let rank: Int
    /// Retained for diagnostics only. The UI explains a pick with its reason
    /// codes and session estimate; a bare number means nothing to a reader.
    let score: Double
    let reasonCodes: [PlayCompassReason]
    let estimatedSessionMinutes: Int
    let estimatedSessionBasis: PlayCompassSessionBasis
    let ownership: PlayCompassOwnership
}

struct PlayCompassOwnership: Equatable, Sendable {
    enum Source: String, Equatable, Sendable {
        case steam = "STEAM"
        case igdb = "IGDB"
    }

    let source: Source
    let externalGameID: String
    let libraryStatus: OwnedLibraryStatus
    let provenance: CatalogProvenance
    let playtimeMinutes: Int?
    let lastPlayedAt: Date?
    /// True only when the server itself established ownership from a real
    /// provider response. A manual entry is never "verified".
    let isVerified: Bool

    /// The contract pins install evidence to "not tracked", so the app must
    /// never imply a game is or is not installed.
    var installStateIsKnown: Bool { false }
}

enum PlayCompassSessionBasis: String, Equatable, Sendable {
    case playlogMedian = "playlog_median"
    case catalogTypicalSession = "catalog_typical_session"
    case genreShortSession = "genre_short_session"
    case genreLongSession = "genre_long_session"
    case defaultEstimate = "default_estimate"
}

/// The complete allowlisted reason vocabulary. Unknown codes are dropped
/// rather than shown raw — an untranslated server token is not an explanation.
enum PlayCompassReason: String, CaseIterable, Equatable, Sendable {
    case fitsAvailableTime = "fits_available_time"
    case shorterThanAvailableTime = "shorter_than_available_time"
    case alreadyInProgress = "already_in_progress"
    case freshStartAvailable = "fresh_start_available"
    case backlogOldestUntouched = "backlog_oldest_untouched"
    case recentlyPlayed = "recently_played"
    case notPlayedRecently = "not_played_recently"
    case genreAffinityMatch = "genre_affinity_match"
    case soloFriendly = "solo_friendly"
    case partyFriendly = "party_friendly"
    case lowEnergyFriendly = "low_energy_friendly"
    case highEnergyFriendly = "high_energy_friendly"
    case comfortPick = "comfort_pick"
    case challengePick = "challenge_pick"
    case platformAvailable = "platform_available"
    case installedOnPlatform = "installed_on_platform"
    case ownedOnSteam = "owned_on_steam"
    case friendOwnedOverlap = "friend_owned_overlap"
    case snoozedRecentlyDeprioritized = "snoozed_recently_deprioritized"
}

// MARK: - Feedback

enum PlayCompassFeedbackAction: String, CaseIterable, Equatable, Sendable {
    case selected = "SELECTED"
    case excluded = "EXCLUDED"
    case snoozed = "SNOOZED"
    case playConfirmed = "PLAY_CONFIRMED"
}

struct PlayCompassFeedback: Equatable, Sendable {
    let catalogGameID: CatalogGameID
    let action: PlayCompassFeedbackAction
    /// Contract caps this at 12 entries.
    let reasonCodes: [PlayCompassReason]
    /// The hash of the round this feedback belongs to.
    let requestHash: String
    let occurredAt: Date
}
