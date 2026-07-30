import Foundation

// MARK: - PlaySessionOutcome

enum PlaySessionOutcome: String, CaseIterable, Equatable, Sendable {
    case resume = "CONTINUE"
    case paused = "PAUSED"
    case dropped = "DROPPED"
    case completed = "COMPLETED"
}

// MARK: - PlaySessionMood
//
// Private user content. Never logged, never sent as a Product Event property,
// never written to a breadcrumb or crash report.

enum PlaySessionMood: String, CaseIterable, Equatable, Sendable {
    case relaxed = "RELAXED"
    case focused = "FOCUSED"
    case excited = "EXCITED"
    case bored = "BORED"
    case frustrated = "FRUSTRATED"
    case nostalgic = "NOSTALGIC"
}

// MARK: - PlaySessionVisibilityOption

enum PlaySessionVisibilityOption: String, CaseIterable, Equatable, Sendable {
    /// The default for every new session. A play record is private until the
    /// user decides otherwise.
    case privateOnly = "PRIVATE"
    case friends = "FRIENDS"
    case everyone = "PUBLIC"

    static let `default`: PlaySessionVisibilityOption = .privateOnly
}

// MARK: - PlaySession

struct PlaySession: Equatable, Sendable, Identifiable {

    /// Contract bounds.
    static let minimumDurationMinutes = 1
    static let maximumDurationMinutes = 1440
    static let maximumNoteLength = 2000

    let id: PlaySessionID
    let catalogGameID: CatalogGameID
    let regionalReleaseID: RegionalReleaseID?
    let playedAt: Date
    let durationMinutes: Int?
    let progressPercent: Int?
    let mood: PlaySessionMood?
    /// Private user content. See `PlaySessionMood`.
    let note: String?
    let outcome: PlaySessionOutcome
    let visibility: PlaySessionVisibilityOption
    let provenance: CatalogProvenance
    /// The idempotency key the record was written under.
    let clientMutationID: String
    let createdAt: Date?
    let updatedAt: Date?

    var hasNote: Bool { !(note ?? "").isEmpty }
}

// MARK: - PlaySessionDraft
//
// What a form produces. Distinct from `PlaySession` because a draft has no
// server identity yet and because it carries the mutation key that makes a
// retry idempotent.

struct PlaySessionDraft: Equatable, Sendable {
    var catalogGameID: CatalogGameID
    var regionalReleaseID: RegionalReleaseID?
    var playedAt: Date
    var durationMinutes: Int?
    var progressPercent: Int?
    var mood: PlaySessionMood?
    var note: String?
    var outcome: PlaySessionOutcome
    var visibility: PlaySessionVisibilityOption
    /// Stable for the lifetime of this draft: created once when the user opens
    /// the form and reused for every retry of the same submission. A different
    /// user action creates a different draft and therefore a different key.
    let clientMutationID: String

    init(
        catalogGameID: CatalogGameID,
        regionalReleaseID: RegionalReleaseID? = nil,
        playedAt: Date = Date(),
        durationMinutes: Int? = nil,
        progressPercent: Int? = nil,
        mood: PlaySessionMood? = nil,
        note: String? = nil,
        outcome: PlaySessionOutcome = .resume,
        visibility: PlaySessionVisibilityOption = .default,
        clientMutationID: String = PlayMutationKey.make()
    ) {
        self.catalogGameID = catalogGameID
        self.regionalReleaseID = regionalReleaseID
        self.playedAt = playedAt
        self.durationMinutes = durationMinutes
        self.progressPercent = progressPercent
        self.mood = mood
        self.note = note
        self.outcome = outcome
        self.visibility = visibility
        self.clientMutationID = clientMutationID
    }

    var trimmedNote: String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(PlaySession.maximumNoteLength))
    }
}

// MARK: - PlayMutationKey

/// Idempotency keys for Playlog mutations.
///
/// The server validates `clientMutationId` against
/// `^[A-Za-z0-9._:-]+$`, 8...120 characters, and enforces
/// `(userId, clientMutationId)` uniqueness — a retried create returns the
/// original record instead of writing a duplicate. A raw UUID string satisfies
/// the pattern, so that is what this produces.
enum PlayMutationKey {
    static func make() -> String {
        UUID().uuidString
    }

    /// A key derived from an existing one, for a *different* operation on the
    /// same record. Delete needs its own key so retrying a delete stays
    /// idempotent without colliding with the create that made the row.
    static func derived(from base: String, suffix: String) -> String {
        let combined = "\(base)-\(suffix)"
        return String(combined.prefix(120))
    }

    static func isValid(_ key: String) -> Bool {
        guard key.count >= 8, key.count <= 120 else { return false }
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:-"
        )
        return key.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

// MARK: - PlayCalendarDay
//
// One local day in the month grid. Derived client-side from typed play
// sessions because the dedicated calendar endpoint's response body is untyped
// in the contract — see docs/product-2.2-contract-gaps.md.

struct PlayCalendarDay: Equatable, Sendable {
    /// `yyyy-MM-dd` in the user's timezone.
    let dayKey: String
    let sessionCount: Int
    /// Sum of the durations that were recorded. Sessions with no duration are
    /// counted in `sessionCount` but contribute nothing here.
    let knownMinutes: Int
    /// True when at least one session that day had no recorded duration, so
    /// `knownMinutes` is a floor.
    let hasSessionsWithUnknownDuration: Bool
}

struct PlayCalendarMonth: Equatable, Sendable {
    let monthKey: String
    let timeZoneIdentifier: String
    let days: [PlayCalendarDay]

    var totalSessions: Int { days.reduce(0) { $0 + $1.sessionCount } }
    var totalKnownMinutes: Int { days.reduce(0) { $0 + $1.knownMinutes } }
    var isEmpty: Bool { days.allSatisfy { $0.sessionCount == 0 } }

    func day(_ key: String) -> PlayCalendarDay? {
        days.first { $0.dayKey == key }
    }
}
