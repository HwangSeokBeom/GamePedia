import Foundation

// MARK: - CatalogProvenance
//
// How a fact came to be believed. The order of the cases is the order of
// trust, and the UI must never present two different levels as if they were
// the same thing — `AI_INFERRED` in particular is never a source of truth and
// can never become a published fact without a human confirming it.

enum CatalogProvenance: String, CaseIterable, Equatable, Sendable {
    case providerVerified = "PROVIDER_VERIFIED"
    case officialSource = "OFFICIAL_SOURCE"
    case editorVerified = "EDITOR_VERIFIED"
    case communityConfirmed = "COMMUNITY_CONFIRMED"
    case userConfirmed = "USER_CONFIRMED"
    case aiInferred = "AI_INFERRED"
    case disputed = "DISPUTED"
    case unknown = "UNKNOWN"

    /// Three visually distinct tiers. Anything not verified by a provider or
    /// an editor must not read as confirmed.
    enum Tier {
        /// A provider response or an editor decision established this.
        case verified
        /// A person asserted it, but nothing independent confirms it.
        case asserted
        /// Nobody confirmed it: inferred, disputed or simply unknown.
        case unconfirmed
    }

    var tier: Tier {
        switch self {
        case .providerVerified, .officialSource, .editorVerified:
            return .verified
        case .userConfirmed, .communityConfirmed:
            return .asserted
        case .aiInferred, .disputed, .unknown:
            return .unconfirmed
        }
    }

    /// True only for values that a reader may take as established fact.
    var isVerified: Bool { tier == .verified }
}

// MARK: - CatalogPublicationStatus

enum CatalogPublicationStatus: String, Equatable, Sendable {
    /// Visible only to the submitter.
    case privateEntry = "PRIVATE"
    /// Submitted for review. Not public, and not approved.
    case pendingReview = "PENDING_REVIEW"
    case published = "PUBLISHED"
    case rejected = "REJECTED"
}

// MARK: - CatalogServiceStatus

enum CatalogServiceStatus: String, Equatable, Sendable {
    case announced = "ANNOUNCED"
    case preRegistration = "PRE_REGISTRATION"
    case live = "LIVE"
    case maintenance = "MAINTENANCE"
    case sunsetAnnounced = "SUNSET_ANNOUNCED"
    case shutdown = "SHUTDOWN"
}

// MARK: - CatalogIdentityProvider

enum CatalogIdentityProvider: String, Equatable, Sendable {
    case igdb = "IGDB"
    case steam = "STEAM"
    case appleAppStore = "APPLE_APP_STORE"
    case googlePlay = "GOOGLE_PLAY"
    case officialSite = "OFFICIAL_SITE"
    case community = "COMMUNITY"
}

// MARK: - CatalogGameSummary

struct CatalogGameSummary: Equatable, Sendable {
    let id: CatalogGameID
    /// The title as the work itself uses it. Server content: never localized
    /// by the app.
    let originalTitle: String
    let slug: String?
    let developerName: String?
    let publisherName: String?
    let firstReleaseDate: String?
    let genres: [String]
    let platforms: [String]
    let publicationStatus: CatalogPublicationStatus
    let titleProvenance: CatalogProvenance
    let identities: [CatalogExternalIdentity]
}

struct CatalogExternalIdentity: Equatable, Sendable {
    let provider: CatalogIdentityProvider
    let externalID: String
    /// `GLOBAL` when the provider key is not region scoped.
    let regionKey: String
    let provenance: CatalogProvenance
    /// 0...1.
    let confidence: Double
}

// MARK: - CatalogGameDetail

struct CatalogGameDetail: Equatable, Sendable {
    let summary: CatalogGameSummary
    let steamTags: [String]
    let supportsSinglePlayer: Bool?
    let supportsMultiplayer: Bool?
    let typicalSessionMinutes: Int?
    let localizations: [CatalogLocalization]
    let regionalReleases: [CatalogRegionalRelease]
    let assets: [CatalogAsset]
    let fieldEvidence: [CatalogFieldEvidence]
    /// True when the id the app asked for was merged into another game. The UI
    /// says so rather than silently showing a different game.
    let resolvedFromMerge: Bool
    let isFollowedByMe: Bool

    var id: CatalogGameID { summary.id }

    /// Localized titles other than the original, which is already on `summary`.
    var aliases: [CatalogLocalization] {
        localizations.filter { $0.kind != .originalTitle }
    }
}

struct CatalogLocalization: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case originalTitle = "ORIGINAL_TITLE"
        case regionalTitle = "REGIONAL_TITLE"
        case alias = "ALIAS"
    }

    let kind: Kind
    let languageCode: String
    let regionCode: String?
    let title: String
    let provenance: CatalogProvenance
}

/// One country/language/platform service edition, with its own operator,
/// availability window and lifecycle status. This is what makes a regional
/// shutdown or a pre-registration expressible at all.
struct CatalogRegionalRelease: Equatable, Sendable {
    let id: RegionalReleaseID
    let countryCode: String
    let languageCode: String
    let platform: String
    let operatorName: String?
    let serverRegion: String?
    let releaseDate: String?
    let shutdownDate: String?
    let serviceStatus: CatalogServiceStatus
    let provenance: CatalogProvenance
}

struct CatalogAsset: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case cover = "COVER"
        case hero = "HERO"
        case screenshot = "SCREENSHOT"
        case logo = "LOGO"
    }

    let kind: Kind
    let url: URL
    let provenance: CatalogProvenance
    let attribution: String?
    /// False for unknown, user-submitted and restricted rights. An asset that
    /// is not usable as a public hero must not be rendered as one.
    let usableAsPublicHero: Bool
}

struct CatalogFieldEvidence: Equatable, Sendable {
    let fieldPath: String
    let provenance: CatalogProvenance
    let confidence: Double
    let sourceType: String
    let sourceURL: URL?
    let observedAt: Date?
}

// MARK: - CatalogCorrection

/// A user's proposed correction. It is a *proposal*: the app never renders it
/// as if the catalog had accepted it.
struct CatalogCorrection: Equatable, Sendable {
    let fieldPath: String
    let proposedValue: String
    let sourceURL: URL?
}
