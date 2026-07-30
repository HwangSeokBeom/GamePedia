import Foundation

// MARK: - QuickAddInput
//
// What the user typed, plus the locale/region the request is scoped to.
//
// The raw text is deliberately hard to leak: this type is a value that lives in
// memory for the length of the flow and is never persisted. Nothing writes it
// to UserDefaults, a file, a log, a breadcrumb, a crash report or the search
// history, and it is discarded when the flow is abandoned or the app leaves
// the foreground. `redactedDescription` is what any diagnostic sees.

struct QuickAddInput: Sendable {

    enum Kind: String, CaseIterable, Sendable {
        /// A natural-language title.
        case text = "TEXT"
        /// An official site, App Store or Google Play URL.
        case url = "URL"
        /// An App Store app id or a Google Play package id.
        case providerID = "PROVIDER_ID"
    }

    static let maximumInputLength = 2000

    let kind: Kind
    /// Raw user input. Sent once, then forgotten.
    let rawInput: String
    let locale: String
    /// Two-letter region code the user confirmed or corrected.
    let regionCode: String
    let platformHint: String?

    init(
        kind: Kind,
        rawInput: String,
        locale: String,
        regionCode: String,
        platformHint: String? = nil
    ) {
        self.kind = kind
        self.rawInput = String(rawInput.prefix(Self.maximumInputLength))
        self.locale = locale
        self.regionCode = regionCode.uppercased()
        self.platformHint = platformHint
    }

    var isSendable: Bool {
        !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && regionCode.count == 2
    }
}

extension QuickAddInput: CustomStringConvertible, CustomDebugStringConvertible {
    /// Both `description` and `debugDescription` are redacted so that a stray
    /// interpolation into a log line cannot print what the user typed. Only
    /// the shape of the input is ever visible.
    var description: String { redactedDescription }
    var debugDescription: String { redactedDescription }

    var redactedDescription: String {
        "QuickAddInput(kind: \(kind.rawValue), length: \(rawInput.count), "
            + "locale: \(locale), region: \(regionCode))"
    }
}

// MARK: - QuickAddPreview

struct QuickAddPreview: Sendable {
    let submissionID: CatalogSubmissionID
    let createdAt: Date?
    /// After this the preview must be re-run; confirming a stale preview is a
    /// contract error, not something to retry silently.
    let expiresAt: Date?
    /// Existing catalog games that may already be what the user meant. Shown
    /// separately from the new draft so "link the one that exists" is always
    /// the more obvious action than "create another".
    let existingCandidates: [QuickAddCandidate]
    let newGameDraft: NewGameDraft
    /// Per-field provenance for the draft. Rendered so the user can see which
    /// values were inferred and therefore need confirming.
    let fieldProvenance: [CatalogFieldEvidence]
    /// At most one, per the contract.
    let clarifyingQuestion: String?
    let resolution: Resolution
    let personalRegistrationAvailable: Bool

    func isExpired(at date: Date) -> Bool {
        guard let expiresAt else { return false }
        return date >= expiresAt
    }

    struct NewGameDraft: Sendable, Equatable {
        /// Nil when no structured title could be derived. The raw
        /// natural-language input is never persisted as a fallback title, so
        /// the user has to supply one.
        let originalTitle: String?
        /// When true, confirm must carry an explicit title or the server
        /// rejects it with SUBMISSION_TITLE_REQUIRED.
        let requiresTitleConfirmation: Bool
    }

    struct Resolution: Sendable, Equatable {
        enum Stage: String, Sendable {
            case providerIdentityExact = "provider_identity_exact"
            case titleExact = "title_exact"
            case fuzzyTitle = "fuzzy_title"
            case aiExtraction = "ai_extraction"
            case manualDraft = "manual_draft"
        }

        let stage: Stage
        let aiUsed: Bool
        /// True when AI failed, timed out, was over quota or returned an
        /// invalid body and the server degraded to a minimal manual draft. The
        /// user must still be able to confirm the fields by hand.
        let aiFallbackUsed: Bool
        let degradeReason: String?
    }
}

// MARK: - QuickAddCandidate

struct QuickAddCandidate: Sendable, Equatable, Identifiable {
    let game: CatalogGameSummary
    let matchReasons: [MatchReason]
    /// 0...1.
    let matchConfidence: Double

    var id: CatalogGameID { game.id }

    /// Why the server thinks this is a match. The distinction that matters:
    /// `providerIdentityExact` means a *verified* provider identity already
    /// exists, while `providerIdentityUnverified` means only an unverified row
    /// does — parsing the syntax of a store URL is not verification.
    enum MatchReason: String, Sendable, Equatable {
        case providerIdentityExact = "provider_identity_exact"
        case providerIdentityUnverified = "provider_identity_unverified"
        case localeAliasExact = "locale_alias_exact"
        case normalizedTitleExact = "normalized_title_exact"
        case compactTitleExact = "compact_title_exact"
        case fuzzyTitleSimilar = "fuzzy_title_similar"
        case developerMatch = "developer_match"
        case platformMatch = "platform_match"
        case regionMatch = "region_match"

        var isVerifiedIdentity: Bool { self == .providerIdentityExact }
    }

    var hasVerifiedIdentityMatch: Bool {
        matchReasons.contains { $0.isVerifiedIdentity }
    }
}

// MARK: - QuickAddConfirmation
//
// The two mutually exclusive ways a submission can be confirmed. Modelling
// them as one enum makes it impossible to send both, which the contract
// rejects, and makes "the user picked an existing game" and "the user
// confirmed a new one" different code paths rather than one ambiguous call.

enum QuickAddConfirmation: Sendable, Equatable {
    /// Link one of the previewed candidates instead of creating a new game.
    case linkExisting(CatalogGameID, requestPublicReview: Bool)
    /// Create a new game from fields the user explicitly confirmed.
    case confirmNewGame(fields: QuickAddConfirmedFields, requestPublicReview: Bool)

    var requestsPublicReview: Bool {
        switch self {
        case .linkExisting(_, let review): return review
        case .confirmNewGame(_, let review): return review
        }
    }

    /// What the user is actually asking for. Personal registration is
    /// immediate and private; a public listing is only ever a *request* that
    /// goes to review, and is never presented as published.
    var outcome: QuickAddOutcome {
        requestsPublicReview ? .pendingPublicReview : .privateRegistration
    }
}

enum QuickAddOutcome: Sendable, Equatable {
    /// A PRIVATE canonical game owned by the submitter. Visible to them only.
    case privateRegistration
    /// PENDING_REVIEW. Not public, not approved — the submitter's own
    /// confirmation is never treated as review approval.
    case pendingPublicReview
}

/// Fields the user explicitly confirmed. Only values a person ticked off get
/// in here; an AI-inferred value that was never confirmed is not sent.
struct QuickAddConfirmedFields: Sendable, Equatable {
    var originalTitle: String?
    var developerName: String?
    var publisherName: String?
    var platforms: [String]

    var isEmpty: Bool {
        originalTitle == nil && developerName == nil
            && publisherName == nil && platforms.isEmpty
    }
}
