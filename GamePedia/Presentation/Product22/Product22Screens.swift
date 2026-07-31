import UIKit

// MARK: - Product 2.2 detail screens
//
// Each screen is a thin `Product22ListViewController` subclass: it decides
// what to ask for and how to phrase the answer, and inherits loading,
// cancellation, stale-response suppression, pull-to-refresh and the five
// display states.
//
// Every one of them consults the product configuration first, so a disabled
// feature costs no network call and settles into an explanation rather than a
// failure with a retry that cannot work.

// MARK: - GameDNAViewController

final class GameDNAViewController: Product22ListViewController {

    private let repository: any PlayIntelligenceRepositing
    private let configStore: ProductConfigStore

    init(repository: any PlayIntelligenceRepositing, configStore: ProductConfigStore) {
        self.repository = repository
        self.configStore = configStore
        super.init(nibName: nil, bundle: nil)
        title = L10n.Product22.Section.gameDNA
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(repository:configStore:)") }

    override func loadContent() async -> Product22ListState {
        guard await configStore.refreshIfNeeded().isEnabled(.gameDNA) else {
            return .disabled(message: L10n.Product22.Section.disabled)
        }
        do {
            let profile = try await repository.gameDNA()
            return .loaded(sections(for: profile))
        } catch {
            return Product22ScreenState.failure(from: error, configStore: configStore)
        }
    }

    private func sections(for profile: GameDNAProfile) -> [Product22ListSection] {
        // Signal count and confidence come first: the reader needs to know how
        // much this is based on before reading what it claims.
        var summaryDetails = [
            "\(L10n.Product22.Section.gameDNA) · \(profile.signalCount)",
            L10n.Product22.Dna.deterministic
        ]
        if !profile.hasEnoughSignal {
            summaryDetails.append(L10n.Product22.Dna.needsMoreData)
            summaryDetails.append(L10n.Product22.Dna.addPlaylog)
        }

        var sections: [Product22ListSection] = [
            Product22ListSection(
                id: "summary",
                title: L10n.Product22.Section.gameDNA,
                rows: [
                    Product22ListRow(
                        id: "confidence",
                        title: profile.confidence.rawValue,
                        details: summaryDetails
                    )
                ]
            )
        ]

        // `missingSignals` and `reasonCodes` are the "why is this thin" answer.
        // They are server tokens, so they are shown as supporting detail under
        // localized copy rather than as the headline.
        if !profile.missingSignals.isEmpty || !profile.reasonCodes.isEmpty {
            sections.append(
                Product22ListSection(
                    id: "gaps",
                    title: L10n.Product22.Dna.needsMoreData,
                    rows: [
                        Product22ListRow(
                            id: "missing",
                            title: L10n.Product22.Dna.addPlaylog,
                            details: profile.missingSignals + profile.reasonCodes
                        )
                    ]
                )
            )
        }
        return sections
    }
}

// MARK: - MonthlyReplayViewController

final class MonthlyReplayViewController: Product22ListViewController {

    private let repository: any PlayIntelligenceRepositing
    private let configStore: ProductConfigStore
    /// The month being shown. Navigation moves this; nothing about the
    /// server's own month boundary is recomputed here.
    private var monthKey: String
    private let timeZoneIdentifier: String

    init(
        monthKey: String,
        repository: any PlayIntelligenceRepositing,
        configStore: ProductConfigStore,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.monthKey = monthKey
        self.repository = repository
        self.configStore = configStore
        self.timeZoneIdentifier = timeZoneIdentifier
        super.init(nibName: nil, bundle: nil)
        title = L10n.Product22.Section.monthlyReplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(monthKey:...)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "chevron.right"),
                primaryAction: UIAction { [weak self] _ in self?.step(by: 1) }
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                primaryAction: UIAction { [weak self] _ in self?.step(by: -1) }
            )
        ]
    }

    /// Steps the month key. This is a *key* calculation, not a boundary
    /// calculation: the window, the timezone and the day count all come back
    /// from the server and are rendered exactly as received.
    private func step(by months: Int) {
        guard let next = Self.month(monthKey, offsetBy: months) else { return }
        monthKey = next
        reload()
    }

    static func month(_ key: String, offsetBy months: Int) -> String? {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return nil }
        let zeroBased = (year * 12 + (month - 1)) + months
        guard zeroBased >= 0 else { return nil }
        return String(format: "%04d-%02d", zeroBased / 12, zeroBased % 12 + 1)
    }

    override func loadContent() async -> Product22ListState {
        guard await configStore.refreshIfNeeded().isEnabled(.monthlyReplay) else {
            return .disabled(message: L10n.Product22.Section.disabled)
        }
        do {
            let replay = try await repository.monthlyReplay(
                monthKey: monthKey, timezone: timeZoneIdentifier
            )
            await MainActor.run { self.title = replay.monthKey }

            // An empty month is an empty state, never an error — but its gaps
            // are still surfaced rather than hidden behind the emptiness.
            if replay.isEmpty, replay.missingData.isEmpty {
                return .empty(message: L10n.Product22.Replay.empty)
            }
            return .loaded(sections(for: replay))
        } catch {
            return Product22ScreenState.failure(from: error, configStore: configStore)
        }
    }

    private func sections(for replay: MonthlyReplay) -> [Product22ListSection] {
        var sections: [Product22ListSection] = []

        // The server's month key, zone and window, verbatim.
        sections.append(
            Product22ListSection(
                id: "window",
                title: replay.monthKey,
                rows: [
                    Product22ListRow(
                        id: "summary",
                        title: replay.timezone,
                        details: [
                            "\(replay.window.localDayCount)",
                            "\(replay.playedDates.count)"
                        ]
                    )
                ]
            )
        )

        var highlights: [Product22ListRow] = []
        if let most = replay.mostPlayedGame {
            var details = ["\(most.totalMinutes)", "\(most.sessionCount)"]
            if !most.minutesKnown { details.append(L10n.Product22.Replay.minutesPartial) }
            highlights.append(
                Product22ListRow(id: "most", title: most.title ?? "", details: details)
            )
        }
        if let surprise = replay.surpriseGame {
            highlights.append(
                Product22ListRow(
                    id: "surprise",
                    title: surprise.title ?? "",
                    details: ["\(surprise.totalMinutes)", "\(surprise.sessionCount)"]
                )
            )
        }
        if !highlights.isEmpty {
            sections.append(Product22ListSection(id: "highlights", title: nil, rows: highlights))
        }

        // Gaps are never swallowed.
        if replay.hasGaps {
            sections.append(
                Product22ListSection(
                    id: "gaps",
                    title: L10n.Product22.Replay.missingData,
                    rows: replay.missingData.map { gap in
                        Product22ListRow(
                            id: gap.code,
                            title: gap.effect,
                            details: [gap.affectedSessionCount, gap.affectedGameCount]
                                .compactMap { $0 }.map(String.init)
                        )
                    }
                )
            )
        }
        return sections
    }
}

// MARK: - PlayCompassViewController

final class PlayCompassViewController: Product22ListViewController {

    private let repository: any PlayIntelligenceRepositing
    private let configStore: ProductConfigStore
    private let onOpenCatalogGame: ((CatalogGameID) -> Void)?

    /// The user's constraints. Only values the contract accepts can be set.
    private var query = PlayCompassQuery(availableMinutes: 60)
    /// The round the on-screen picks came from. Feedback carries this hash so
    /// the server can attribute it to the request that produced it.
    private var requestHash: String?
    private var recommendations: [PlayCompassRecommendation] = []

    init(
        repository: any PlayIntelligenceRepositing,
        configStore: ProductConfigStore,
        onOpenCatalogGame: ((CatalogGameID) -> Void)? = nil
    ) {
        self.repository = repository
        self.configStore = configStore
        self.onOpenCatalogGame = onOpenCatalogGame
        super.init(nibName: nil, bundle: nil)
        title = L10n.Product22.Section.playCompass
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(repository:configStore:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The three quick choices, plus whatever the detail picker allows.
        // Nothing outside the contract's 5...1440 range can be selected.
        let items = PlayCompassQuery.quickChoices.map { minutes in
            UIAction(title: "\(minutes)") { [weak self] _ in
                self?.query = PlayCompassQuery(
                    availableMinutes: minutes,
                    mood: self?.query.mood,
                    energy: self?.query.energy,
                    soloOrParty: self?.query.soloOrParty,
                    continueOrStart: self?.query.continueOrStart
                )
                self?.reload()
            }
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            menu: UIMenu(children: items)
        )
    }

    override func loadContent() async -> Product22ListState {
        guard await configStore.refreshIfNeeded().isEnabled(.playCompass) else {
            return .disabled(message: L10n.Product22.Section.disabled)
        }
        do {
            let result = try await repository.recommend(query)
            requestHash = result.requestHash
            recommendations = result.recommendations

            guard !result.recommendations.isEmpty else {
                switch result.emptyReason {
                case .noOwnedPlayingOrBacklogGames:
                    return .empty(message: L10n.Product22.Compass.emptyNoOwned)
                case .noCandidateMatchedConstraints, nil:
                    return .empty(message: L10n.Product22.Compass.emptyNoMatch)
                }
            }
            return .loaded(sections(for: result))
        } catch {
            return Product22ScreenState.failure(from: error, configStore: configStore)
        }
    }

    private func sections(for result: PlayCompassResult) -> [Product22ListSection] {
        var guarantees = [L10n.Product22.Compass.ownedOnly, L10n.Product22.Compass.installUnknown]
        if result.freshness.isStale { guarantees.append(L10n.Product22.Compass.stale) }
        if result.confidence == .low { guarantees.append(L10n.Product22.Compass.confidenceLow) }

        return [
            Product22ListSection(
                id: "guarantees",
                title: nil,
                rows: [Product22ListRow(id: "note", title: L10n.Product22.Compass.cta, details: guarantees)]
            ),
            Product22ListSection(
                id: "picks",
                title: L10n.Product22.Section.playCompass,
                // At most three, which the contract also caps.
                rows: result.recommendations.prefix(3).map { recommendation in
                    var details = recommendation.reasonCodes.compactMap(TodayDisplayModel.text(for:))
                    details.append(TodayDisplayModel.text(for: recommendation.estimatedSessionBasis))
                    details.append(
                        recommendation.ownership.isVerified
                            ? L10n.Product22.Compass.ownershipVerified
                            : L10n.Product22.Compass.ownershipUnverified
                    )
                    return Product22ListRow(
                        id: recommendation.catalogGameID.wireValue,
                        title: recommendation.title ?? "",
                        subtitle: nil,
                        details: details,
                        actionTitle: L10n.Common.Button.confirm
                    )
                }
            )
        ]
    }

    override func didSelectRow(_ row: Product22ListRow, in section: Product22ListSection) {
        guard section.id == "picks",
              let id = CatalogGameID(uuidString: row.id),
              let recommendation = recommendations.first(where: { $0.catalogGameID == id }),
              let requestHash else { return }

        // Feedback carries the round's hash and the same reason codes the user
        // was shown, so the server can attribute it to this recommendation.
        let feedback = PlayCompassFeedback(
            catalogGameID: id,
            action: .selected,
            reasonCodes: recommendation.reasonCodes,
            requestHash: requestHash,
            occurredAt: Date()
        )
        Task { [repository] in
            // Feedback is best-effort: a failure must not block the user from
            // opening the game they just chose.
            try? await repository.sendFeedback(feedback)
        }
        onOpenCatalogGame?(id)
    }
}

// MARK: - Product22ScreenState

enum Product22ScreenState {
    /// Maps a thrown error into a display state, converging the app on a new
    /// kill-switch state when the server reports one.
    static func failure(
        from error: any Error,
        configStore: ProductConfigStore
    ) -> Product22ListState {
        let mapped = Product22ErrorMapper.map(error)
        switch mapped {
        case .featureUnavailable(let reason):
            Task { await configStore.handleFeatureUnavailable(reason) }
            return .disabled(message: L10n.Product22.Section.disabled)
        case .unauthorized:
            return .disabled(message: L10n.Common.Error.unauthorized)
        case .transport(let message) where message == Product22Error.cancellationMarker:
            return .loading
        default:
            return .failed(message: L10n.Common.Error.network)
        }
    }
}
