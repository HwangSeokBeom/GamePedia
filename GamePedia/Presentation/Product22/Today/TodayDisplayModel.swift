import Foundation

// MARK: - TodayDisplayModel
//
// Turns a `TodayFeed` into exactly what the Home collection renders.
//
// Everything user-facing is decided here rather than in a cell, so the rules
// that matter are in one testable place:
//
//   - a `disabled` section becomes an explanation, never a retry button. A
//     kill switch cannot be retried, and offering the user a button that
//     cannot work is worse than saying nothing.
//   - an `unavailable` section becomes a retry scoped to itself.
//   - an `ok` section with no items is an empty state, not an error.
//   - a server reason code the app does not recognise is dropped rather than
//     shown raw; an untranslated token is not an explanation.
//   - nothing here formats a game title, a developer name or a headline —
//     those are server content and pass through untouched.

struct TodayDisplayModel: Equatable {

    let sections: [Section]
    /// Shown as a quiet notice, not an error: a partial feed is still a feed.
    let showsPartialFailureNotice: Bool
    /// True when what is on screen came from cache past its freshness window.
    let isStale: Bool

    struct Section: Equatable, Hashable {
        let key: TodaySectionKey
        let title: String
        let state: State

        enum State: Equatable, Hashable {
            case items([Item])
            /// No content, but nothing went wrong.
            case empty(message: String)
            /// The feature is off. No retry — see the type comment.
            case disabled(message: String)
            /// It failed. Retryable, and only this section.
            case unavailable(message: String, retryTitle: String)
        }

        var isRetryable: Bool {
            if case .unavailable = state { return true }
            return false
        }
    }

    // MARK: Item

    struct Item: Equatable, Hashable {
        let id: String
        /// Server content — a game title or an article headline. Never
        /// localized, never reformatted.
        let title: String
        let subtitle: String?
        /// Short explanatory lines derived from reason codes and provenance.
        let details: [String]
        let accessibilityLabel: String
        let action: Action?

        enum Action: Equatable, Hashable {
            case openCatalogGame(CatalogGameID)
            case openArticle(slug: String)
            case openMonthlyReplay(monthKey: String)
            case openGameDNA
            case openPlayCompass
        }
    }

    // MARK: Building

    init(feed: TodayFeed, isStale: Bool) {
        self.isStale = isStale
        self.showsPartialFailureNotice = feed.partialFailure
        self.sections = feed.sections.map(Self.section(from:))
    }

    /// The state Home shows while the first Today load is in flight.
    static func skeleton() -> TodayDisplayModel {
        TodayDisplayModel(sections: [], showsPartialFailureNotice: false, isStale: false)
    }

    private init(sections: [Section], showsPartialFailureNotice: Bool, isStale: Bool) {
        self.sections = sections
        self.showsPartialFailureNotice = showsPartialFailureNotice
        self.isStale = isStale
    }

    // MARK: Section mapping

    private static func section(from section: TodaySection) -> Section {
        Section(key: section.key, title: title(for: section.key), state: state(from: section))
    }

    static func title(for key: TodaySectionKey) -> String {
        switch key {
        case .playCompass: return L10n.Product22.Section.playCompass
        case .gameDNA: return L10n.Product22.Section.gameDNA
        case .gameBriefing: return L10n.Product22.Section.gameBriefing
        case .backlogRescue: return L10n.Product22.Section.backlogRescue
        case .spoilerFreeStartGuide: return L10n.Product22.Section.spoilerFreeStartGuide
        case .editorialCuration: return L10n.Product22.Section.editorialCuration
        case .monthlyReplay: return L10n.Product22.Section.monthlyReplay
        case .friendActivity: return L10n.Product22.Section.friendActivity
        }
    }

    private static func state(from section: TodaySection) -> Section.State {
        switch section.state {
        case .disabled:
            // The reason code is a server token; it is not shown. The user is
            // told the feature is off, and given nothing to press.
            return .disabled(message: L10n.Product22.Section.disabled)

        case .unavailable:
            return .unavailable(
                message: L10n.Product22.Section.unavailable,
                retryTitle: L10n.Product22.Section.retry
            )

        case .content(let content):
            let items = self.items(from: content)
            if items.isEmpty {
                return .empty(message: emptyMessage(for: content))
            }
            return .items(items)
        }
    }

    private static func emptyMessage(for content: TodaySection.Content) -> String {
        if case .playCompass(let compass) = content {
            switch compass.emptyReason {
            case .noOwnedPlayingOrBacklogGames: return L10n.Product22.Compass.emptyNoOwned
            case .noCandidateMatchedConstraints: return L10n.Product22.Compass.emptyNoMatch
            case nil: break
            }
        }
        return L10n.Product22.Section.empty
    }

    // MARK: Item mapping

    private static func items(from content: TodaySection.Content) -> [Item] {
        switch content {
        case .playCompass(let compass):
            return compass.recommendations.map { item(from: $0, ownedOnly: compass.ownedOnly, freshness: compass.freshness) }

        case .gameDNA(let dna):
            return [item(from: dna)]

        case .gameBriefing(let items, _):
            return items.map(item(from:))

        case .backlogRescue(let items, _):
            return items.map(item(from:))

        case .spoilerFreeStartGuide(let items, _):
            return items.map(item(from:))

        case .editorialCuration(let articles, _):
            return articles.map(item(from:))

        case .monthlyReplay(let replay):
            return replay.isEmpty ? [] : [item(from: replay)]

        case .friendActivity(let items, _):
            return items.map(item(from:))
        }
    }

    private static func item(
        from recommendation: PlayCompassRecommendation,
        ownedOnly: Bool,
        freshness: PlayCompassFreshness
    ) -> Item {
        var details: [String] = []
        // Reason codes first: they are why this pick is here. The raw score is
        // never shown — a number means nothing to a reader.
        details.append(contentsOf: recommendation.reasonCodes.compactMap(text(for:)))
        details.append(text(for: recommendation.estimatedSessionBasis))
        details.append(
            recommendation.ownership.isVerified
                ? L10n.Product22.Compass.ownershipVerified
                : L10n.Product22.Compass.ownershipUnverified
        )
        if ownedOnly { details.append(L10n.Product22.Compass.ownedOnly) }
        // Install state is not tracked, and the UI says so rather than
        // implying either answer.
        details.append(L10n.Product22.Compass.installUnknown)
        if freshness.isStale { details.append(L10n.Product22.Compass.stale) }

        let title = recommendation.title ?? ""
        return Item(
            id: recommendation.catalogGameID.wireValue,
            title: title,
            subtitle: nil,
            details: details,
            accessibilityLabel: ([title] + details).joined(separator: ", "),
            action: .openCatalogGame(recommendation.catalogGameID)
        )
    }

    private static func item(from dna: TodayGameDNASummary) -> Item {
        var details: [String] = []
        // Signal count and confidence come first — the reader needs to know
        // how much this is based on before they read what it says.
        details.append(L10n.Product22.Dna.deterministic)
        if dna.confidence == .low || dna.signalCount == 0 {
            details.append(L10n.Product22.Dna.needsMoreData)
            details.append(L10n.Product22.Dna.addPlaylog)
        }
        // Server content: genre names pass through untranslated.
        details.append(contentsOf: dna.topGenres.prefix(3).map(\.genre))

        return Item(
            id: "gameDNA",
            title: L10n.Product22.Section.gameDNA,
            subtitle: nil,
            details: details,
            accessibilityLabel: ([L10n.Product22.Section.gameDNA] + details).joined(separator: ", "),
            action: .openGameDNA
        )
    }

    private static func item(from briefing: TodayBriefingItem) -> Item {
        let details = briefing.noteworthyReleases.map { release in
            [release.countryCode, release.platform].joined(separator: " · ")
        }
        return Item(
            id: briefing.catalogGameID.wireValue,
            title: briefing.title,
            subtitle: nil,
            details: details,
            accessibilityLabel: ([briefing.title] + details).joined(separator: ", "),
            action: .openCatalogGame(briefing.catalogGameID)
        )
    }

    private static func item(from backlog: TodayBacklogItem) -> Item {
        Item(
            id: backlog.catalogGameID.wireValue,
            title: backlog.title,
            subtitle: nil,
            details: [L10n.Product22.Reason.backlogOldestUntouched],
            accessibilityLabel: "\(backlog.title), \(L10n.Product22.Reason.backlogOldestUntouched)",
            action: .openCatalogGame(backlog.catalogGameID)
        )
    }

    private static func item(from guide: TodayStartGuideItem) -> Item {
        var details: [String] = []
        if guide.soloFriendly == true { details.append(L10n.Product22.Reason.soloFriendly) }
        if guide.partyFriendly == true { details.append(L10n.Product22.Reason.partyFriendly) }
        details.append(contentsOf: guide.genres.prefix(2))
        return Item(
            id: guide.catalogGameID.wireValue,
            title: guide.title,
            subtitle: nil,
            details: details,
            accessibilityLabel: ([guide.title] + details).joined(separator: ", "),
            action: .openCatalogGame(guide.catalogGameID)
        )
    }

    private static func item(from card: ArticleCard) -> Item {
        var details: [String] = []
        // A corrected article must read as corrected before it is opened.
        if card.isCorrected { details.append(L10n.Product22.Article.corrected) }
        if card.heroImage == nil, card.heroImageWithheldReason != nil {
            details.append(L10n.Product22.Article.heroWithheld)
        }
        return Item(
            id: card.slug,
            title: card.headline,       // server content
            subtitle: card.excerpt,     // server content
            details: details,
            accessibilityLabel: ([card.headline, card.excerpt] + details).joined(separator: ", "),
            action: .openArticle(slug: card.slug)
        )
    }

    private static func item(from replay: TodayReplaySummary) -> Item {
        var details: [String] = []
        if let most = replay.mostPlayedGame {
            if let title = most.title { details.append(title) }   // server content
            if !most.minutesKnown { details.append(L10n.Product22.Replay.minutesPartial) }
        }
        if !replay.missingData.isEmpty {
            details.append(L10n.Product22.Replay.missingData)
        }
        return Item(
            id: replay.monthKey,
            title: L10n.Product22.Section.monthlyReplay,
            subtitle: nil,
            details: details,
            accessibilityLabel: ([L10n.Product22.Section.monthlyReplay] + details).joined(separator: ", "),
            action: .openMonthlyReplay(monthKey: replay.monthKey)
        )
    }

    private static func item(from activity: TodayFriendActivityItem) -> Item {
        // Friend activity routes to the canonical game only when the server
        // attached one. There is no fallback that invents a destination.
        let action: Item.Action? = activity.catalogGameID.map { .openCatalogGame($0) }
        return Item(
            id: activity.activityID.uuidString,
            title: activity.kind.rawValue,
            subtitle: nil,
            details: [],
            accessibilityLabel: activity.kind.rawValue,
            action: action
        )
    }

    // MARK: Reason code vocabulary

    /// Unknown codes yield nil and are dropped by the caller's `compactMap`.
    static func text(for reason: PlayCompassReason) -> String? {
        switch reason {
        case .fitsAvailableTime: return L10n.Product22.Reason.fitsAvailableTime
        case .shorterThanAvailableTime: return L10n.Product22.Reason.shorterThanAvailableTime
        case .alreadyInProgress: return L10n.Product22.Reason.alreadyInProgress
        case .freshStartAvailable: return L10n.Product22.Reason.freshStartAvailable
        case .backlogOldestUntouched: return L10n.Product22.Reason.backlogOldestUntouched
        case .recentlyPlayed: return L10n.Product22.Reason.recentlyPlayed
        case .notPlayedRecently: return L10n.Product22.Reason.notPlayedRecently
        case .genreAffinityMatch: return L10n.Product22.Reason.genreAffinityMatch
        case .soloFriendly: return L10n.Product22.Reason.soloFriendly
        case .partyFriendly: return L10n.Product22.Reason.partyFriendly
        case .lowEnergyFriendly: return L10n.Product22.Reason.lowEnergyFriendly
        case .highEnergyFriendly: return L10n.Product22.Reason.highEnergyFriendly
        case .comfortPick: return L10n.Product22.Reason.comfortPick
        case .challengePick: return L10n.Product22.Reason.challengePick
        case .platformAvailable: return L10n.Product22.Reason.platformAvailable
        case .installedOnPlatform: return L10n.Product22.Reason.installedOnPlatform
        case .ownedOnSteam: return L10n.Product22.Reason.ownedOnSteam
        case .friendOwnedOverlap: return L10n.Product22.Reason.friendOwnedOverlap
        case .snoozedRecentlyDeprioritized: return L10n.Product22.Reason.snoozedRecentlyDeprioritized
        }
    }

    static func text(for basis: PlayCompassSessionBasis) -> String {
        switch basis {
        case .playlogMedian: return L10n.Product22.Basis.playlogMedian
        case .catalogTypicalSession: return L10n.Product22.Basis.catalogTypicalSession
        case .genreShortSession: return L10n.Product22.Basis.genreShortSession
        case .genreLongSession: return L10n.Product22.Basis.genreLongSession
        case .defaultEstimate: return L10n.Product22.Basis.defaultEstimate
        }
    }
}
