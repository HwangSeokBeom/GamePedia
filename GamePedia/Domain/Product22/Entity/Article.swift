import Foundation

// MARK: - ArticleStatus
//
// Only the two publicly readable states exist here. Any other workflow state
// is a 404 to a reader, so the app has no way to represent one and no way to
// leak one.

enum ArticleStatus: String, Equatable, Sendable {
    case published = "PUBLISHED"
    /// The article was corrected after publication. This is never rendered the
    /// same as PUBLISHED: a reader has to be able to see that the text changed.
    case corrected = "CORRECTED"
}

// MARK: - ArticleHeroImage

/// A hero image the contract has already rights-reviewed. There is no way to
/// construct one from an arbitrary URL, so the app cannot promote an
/// unreviewed asset into a hero slot.
struct ArticleHeroImage: Equatable, Sendable {
    enum RightsStatus: String, Equatable, Sendable {
        case providerLicensed = "PROVIDER_LICENSED"
        case officialPressKit = "OFFICIAL_PRESS_KIT"
        case cleared = "CLEARED"
    }

    let url: URL
    let rightsStatus: RightsStatus
    let attribution: String?
}

// MARK: - ArticleRelatedGame

struct ArticleRelatedGame: Equatable, Sendable {
    enum Relation: String, Equatable, Sendable {
        case subject = "SUBJECT"
        case mentioned = "MENTIONED"
        case related = "RELATED"
    }

    /// Canonical UUID, preserved exactly. Never converted to a legacy integer.
    let catalogGameID: CatalogGameID
    let relation: Relation
}

// MARK: - ArticleCard
//
// What the Today feed carries. Deliberately has no body: a Today response can
// hold several articles and shipping bodies for cards the reader may never
// open wastes their data. The body is a separate fetch by slug.

struct ArticleCard: Equatable, Sendable, Identifiable {
    let slug: String
    let status: ArticleStatus
    let locale: String
    /// Server content. Not routed through L10n.
    let headline: String
    let excerpt: String
    let publishedAt: Date?
    let correctedAt: Date?
    let heroImage: ArticleHeroImage?
    /// Present when a hero exists but could not be cleared for public use. The
    /// UI shows a stable placeholder and, where useful, this reason.
    let heroImageWithheldReason: String?
    let relatedGames: [ArticleRelatedGame]
    let sourceCount: Int

    var id: String { slug }

    var isCorrected: Bool { status == .corrected }
}

// MARK: - Article
//
// The full readable article.

struct Article: Equatable, Sendable {
    /// The only body format the app renders. The contract pins it to
    /// `commonmark-no-html`; anything else is refused rather than guessed at.
    static let supportedBodyFormat = "commonmark-no-html"

    let slug: String
    let status: ArticleStatus
    let locale: String
    let headline: String
    let excerpt: String
    /// CommonMark with HTML disabled. Rendered with a Markdown renderer that
    /// has raw HTML off and inline remote images suppressed — never a web view.
    let bodyMarkdown: String
    let publishedAt: Date?
    let correctedAt: Date?
    let revision: Revision
    let heroImageWithheldReason: String?
    let sources: [ArticleSource]

    // Note the absence of `heroImage` and `relatedGames`.
    //
    // `PublicArticle` declares both as bare untyped objects — unlike
    // `ArticleSummary`, which uses proper `$ref`s — so they cannot be read off
    // the detail response without guessing key names. The reader screen takes
    // them from the typed `ArticleCard` it was opened from instead; an article
    // reached without a card simply shows no hero and no related games rather
    // than inventing them. See docs/product-2.2-contract-gaps.md.

    var isCorrected: Bool { status == .corrected }

    struct Revision: Equatable, Sendable {
        let number: Int
        let status: ArticleStatus
        /// Non-empty whenever the revision is CORRECTED — the server refuses to
        /// record a correction without one, so the UI can rely on having
        /// something to show the reader.
        let changeNote: String?
        let createdAt: Date
    }
}

// MARK: - ArticleSource

struct ArticleSource: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case officialRSS = "OFFICIAL_RSS"
        case steamNews = "STEAM_NEWS"
        case officialSite = "OFFICIAL_SITE"
        case editorManual = "EDITOR_MANUAL"
    }

    let kind: Kind
    let publisherKey: String
    let headline: String
    let excerpt: String?
    let url: URL
    let publishedAt: Date?
    let fetchedAt: Date
    let provenance: CatalogProvenance

    /// Only an HTTPS source may be opened. A plaintext link is shown but not
    /// tappable rather than silently upgraded or silently opened.
    var isOpenable: Bool {
        url.scheme?.lowercased() == "https"
    }
}
