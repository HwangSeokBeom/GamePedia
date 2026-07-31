import Foundation

// MARK: - CatalogSubmissionStatus
//
// The lifecycle of a quick-add submission.
//
// The contract lists six values, but this server only ever writes four:
// PREVIEW, PERSONAL_CONFIRMED, PENDING_REVIEW and EXPIRED. APPROVED and
// REJECTED exist in the column for a future editorial flow, and the contract
// documents them precisely so a value written by that flow decodes rather than
// failing the whole response. Every one of the six is handled here for the
// same reason.

enum CatalogSubmissionStatus: String, CaseIterable, Equatable, Sendable {
    /// Previewed but not confirmed. Still expirable.
    case preview = "PREVIEW"
    /// Confirmed into the submitter's own private catalog.
    case personalConfirmed = "PERSONAL_CONFIRMED"
    /// A public listing was requested and is awaiting review. Not approved,
    /// and never published by the request alone.
    case pendingReview = "PENDING_REVIEW"
    /// An editor approved the public listing.
    case approved = "APPROVED"
    /// An editor declined the public listing.
    case rejected = "REJECTED"
    /// The preview window closed before it was confirmed.
    case expired = "EXPIRED"

    /// True once the submission has produced something the user owns.
    var isConfirmed: Bool {
        switch self {
        case .personalConfirmed, .pendingReview, .approved: return true
        case .preview, .rejected, .expired: return false
        }
    }

    /// True when the user can still act on it by confirming.
    var isActionable: Bool { self == .preview }

    /// True when the outcome is settled and nothing further will happen
    /// without a new submission.
    var isTerminal: Bool {
        switch self {
        case .approved, .rejected, .expired: return true
        case .preview, .personalConfirmed, .pendingReview: return false
        }
    }
}

// MARK: - CatalogSubmissionInputType

enum CatalogSubmissionInputType: String, Equatable, Sendable {
    case text = "TEXT"
    case url = "URL"
    case providerID = "PROVIDER_ID"
}

// MARK: - SubmissionConfirmResult
//
// What a confirmation actually produced.
//
// All three paths — created, linked, replayed — return the same fields, so
// this reads `createdNewGame` and `isIdempotentReplay` rather than branching on
// the HTTP status code.

struct SubmissionConfirmResult: Equatable, Sendable {
    let submissionID: CatalogSubmissionID
    let status: CatalogSubmissionStatus
    /// The canonical game this resolved to — created or linked. Non-null on
    /// every create and link path; null only on an idempotent replay of a
    /// submission that left PREVIEW without linking a game.
    let catalogGameID: CatalogGameID?
    /// True only when *this* request created the game. A replay reports false.
    let createdNewGame: Bool
    /// True when a concurrent or repeated confirm lost the PREVIEW claim and
    /// this is the already-committed outcome.
    let isIdempotentReplay: Bool
    let publicationStatus: CatalogPublicationStatus
    /// Present when a verified identity already holds the parsed provider key
    /// on a different game. Nothing is merged; the conflict is reported so the
    /// user can be offered the existing game instead.
    let identityConflict: SubmissionIdentityConflict?

    /// Where the user should be taken next, if anywhere.
    ///
    /// A conflict wins over the resolved game: if a verified identity already
    /// exists elsewhere, that existing game is the honest destination.
    var deepLinkTarget: CatalogGameID? {
        identityConflict?.existingCatalogGameID ?? catalogGameID
    }
}

struct SubmissionIdentityConflict: Equatable, Sendable {
    let provider: CatalogIdentityProvider
    /// The game that already holds this verified provider identity.
    let existingCatalogGameID: CatalogGameID
    /// The contract declares exactly one reason today.
    let reasonCode: String
}

// MARK: - CatalogSubmissionState
//
// The full readable state of one submission, for the account that created it.

struct CatalogSubmissionState: Equatable, Sendable {
    let submissionID: CatalogSubmissionID
    let status: CatalogSubmissionStatus
    let inputType: CatalogSubmissionInputType
    let locale: String
    let regionCode: String
    let platformHint: String?
    /// Null when the stored draft failed re-validation; `isDraftReadable`
    /// reports which, and the user is asked to preview again rather than shown
    /// a half-empty form.
    let draft: CatalogSubmissionDraft?
    let isDraftReadable: Bool
    /// Counts and reason codes for the candidates the preview found. Every
    /// field inside is optional because the column is stored as JSON and
    /// returned without re-validation, so a row written by an earlier revision
    /// must still decode.
    let candidateSummary: CatalogSubmissionCandidateSummary?
    /// At most one, per the contract.
    let clarifyingQuestion: String?
    let aiFallbackUsed: Bool
    /// The canonical game this resolved to, or nil before confirmation.
    let catalogGameID: CatalogGameID?
    let publicationStatus: CatalogPublicationStatus
    let expiresAt: Date
    /// Evaluated against the server clock at read time. A confirm after this
    /// is a 409, so the client does not re-derive it from the local clock.
    let isExpired: Bool
    let createdAt: Date
    let updatedAt: Date

    /// True when the user can still confirm this submission.
    var canConfirm: Bool { status.isActionable && !isExpired && isDraftReadable }
}

/// Counts and reason codes only — never the raw input, which the server does
/// not store and never returns.
struct CatalogSubmissionCandidateSummary: Equatable, Sendable {
    /// Shape version written by the preview. Nil on a row from before the
    /// field existed.
    let version: Int?
    let candidateCount: Int?
    let catalogGameIDs: [CatalogGameID]
    let reasonCodes: [String]

    /// True when the summary carries nothing usable — an older row, or one the
    /// preview wrote before it recorded candidates. Callers show "no
    /// candidates recorded" rather than "0 candidates found", because those
    /// are different facts.
    var isEmptyShape: Bool {
        version == nil && candidateCount == nil && catalogGameIDs.isEmpty && reasonCodes.isEmpty
    }
}

// MARK: - CatalogSubmissionDraft

struct CatalogSubmissionDraft: Equatable, Sendable {
    /// Nil until a title exists as a structured field. The raw
    /// natural-language input is never stored here as a fallback.
    let originalTitle: String?
    let requiresTitleConfirmation: Bool
    let developerName: String?
    let publisherName: String?
    let firstReleaseDate: String?
    let genres: [String]
    let platforms: [String]
    let supportsSinglePlayer: Bool?
    let supportsMultiplayer: Bool?
    let typicalSessionMinutes: Int?
    let localizations: [CatalogSubmissionDraftLocalization]
    let regionalReleases: [CatalogSubmissionDraftRegionalRelease]
    /// Provider keys parsed out of the submitted text. Parsing is not
    /// verification, so these are claims and never occupy a global provider
    /// key — the UI must not present them as confirmed identities.
    let identities: [CatalogSubmissionDraftIdentity]
    let fieldProvenance: [CatalogSubmissionDraftProvenance]
}

struct CatalogSubmissionDraftLocalization: Equatable, Sendable {
    let kind: CatalogLocalization.Kind
    let languageCode: String
    let regionCode: String?
    let title: String
}

struct CatalogSubmissionDraftRegionalRelease: Equatable, Sendable {
    let countryCode: String
    let languageCode: String
    let platform: String
    let operatorName: String?
    let serverRegion: String?
    let releaseDate: String?
    let shutdownDate: String?
    let serviceStatus: CatalogServiceStatus
}

struct CatalogSubmissionDraftIdentity: Equatable, Sendable {
    let provider: CatalogIdentityProvider
    let externalID: String
    let regionKey: String
}

struct CatalogSubmissionDraftProvenance: Equatable, Sendable {
    let fieldPath: String
    let provenance: CatalogProvenance
    /// 0...1.
    let confidence: Double
}

// MARK: - Paged results
//
// `nextCursor` is an opaque continuation token. It is passed back verbatim and
// never parsed: its encoding is a server detail.

struct CatalogSearchPageResult: Equatable, Sendable {
    let games: [CatalogGameSummary]
    let nextCursor: String?
    /// How the page was produced. `emptyQuery` and `noMatch` are different
    /// facts from "no results", and the UI says so.
    let matchedBy: MatchedBy
    let limit: Int

    var hasMore: Bool { nextCursor != nil }

    enum MatchedBy: String, Equatable, Sendable {
        /// The query normalised to nothing — a punctuation-only query does.
        case emptyQuery = "empty_query"
        /// Nothing scored above the threshold.
        case noMatch = "no_match"
        case normalizedTitleExact = "normalized_title_exact"
        case ranked = "ranked"
    }
}

struct PlaySessionPageResult: Equatable, Sendable {
    let sessions: [PlaySession]
    let nextCursor: String?
    let limit: Int

    var hasMore: Bool { nextCursor != nil }
}
