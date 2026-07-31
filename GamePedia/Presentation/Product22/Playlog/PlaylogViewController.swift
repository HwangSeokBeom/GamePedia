import UIKit

// MARK: - PlaylogViewController
//
// The play-session list and month grid for one canonical game, or for the
// whole account when `catalogGameID` is nil.
//
// The month grid is derived from typed sessions rather than fetched: the
// calendar endpoint's response body is untyped in the contract, so reading it
// would mean guessing key names. See docs/product-2.2-contract-gaps.md.

final class PlaylogViewController: Product22ListViewController {

    private let catalogGameID: CatalogGameID?
    private let repository: any PlaylogRepositing
    private let configStore: ProductConfigStore
    /// Server content — the game's own title. Shown as received.
    private let gameTitle: String?

    private var sessions: [PlaySession] = []
    private var monthKey: String
    private let timeZone: TimeZone

    init(
        catalogGameID: CatalogGameID?,
        gameTitle: String?,
        repository: any PlaylogRepositing,
        configStore: ProductConfigStore,
        timeZone: TimeZone = .current,
        monthKey: String? = nil
    ) {
        self.catalogGameID = catalogGameID
        self.gameTitle = gameTitle
        self.repository = repository
        self.configStore = configStore
        self.timeZone = timeZone
        self.monthKey = monthKey ?? Self.currentMonthKey(in: timeZone)
        super.init(nibName: nil, bundle: nil)
        title = L10n.Product22.Playlog.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(catalogGameID:...)") }

    static func currentMonthKey(in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", components.year ?? 1970, components.month ?? 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Adding a session is only offered when there is a game to attach it
        // to — the contract requires a catalogGameId on every session.
        if catalogGameID != nil {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                systemItem: .add,
                primaryAction: UIAction { [weak self] _ in self?.presentForm(editing: nil) }
            )
            navigationItem.rightBarButtonItem?.accessibilityLabel = L10n.Product22.Playlog.add
        }
    }

    // MARK: Loading

    override func loadContent() async -> Product22ListState {
        guard await configStore.refreshIfNeeded().isEnabled(.playlog) else {
            return .disabled(message: L10n.Product22.Section.disabled)
        }
        do {
            // The month window bounds the fetch so the grid and the list are
            // built from the same typed rows.
            let window = PlayCalendarDeriver.window(monthKey: monthKey, timeZone: timeZone)
            let fetched = try await repository.sessions(
                for: catalogGameID, from: window?.start, to: window?.end
            )
            sessions = fetched.sorted { $0.playedAt > $1.playedAt }

            guard !sessions.isEmpty else {
                return .empty(message: L10n.Product22.Playlog.empty)
            }
            return .loaded(buildSections())
        } catch {
            return Product22ScreenState.failure(from: error, configStore: configStore)
        }
    }

    private func buildSections() -> [Product22ListSection] {
        let calendar = PlayCalendarDeriver.month(
            monthKey: monthKey, timeZone: timeZone, sessions: sessions
        )

        var sections: [Product22ListSection] = []

        // Month summary. The day buckets are the client's own aggregation of
        // typed sessions, in the user's timezone.
        sections.append(
            Product22ListSection(
                id: "calendar",
                title: L10n.Product22.Playlog.calendar,
                rows: calendar.days.map { day in
                    var details = ["\(day.sessionCount)"]
                    if day.knownMinutes > 0 { details.append("\(day.knownMinutes)") }
                    if day.hasSessionsWithUnknownDuration {
                        details.append(L10n.Product22.Playlog.durationUnknown)
                    }
                    return Product22ListRow(id: "day-\(day.dayKey)", title: day.dayKey, details: details)
                }
            )
        )

        // The sessions themselves. A note is never rendered into the row's
        // accessibility label beyond its own text, and never leaves the device
        // in analytics.
        sections.append(
            Product22ListSection(
                id: "sessions",
                title: L10n.Product22.Playlog.title,
                rows: sessions.map { session in
                    var details: [String] = [Product22Vocabulary.text(for: session.outcome)]
                    if let minutes = session.durationMinutes {
                        details.append("\(minutes)")
                    } else {
                        details.append(L10n.Product22.Playlog.durationUnknown)
                    }
                    if let progress = session.progressPercent { details.append("\(progress)%") }
                    if let mood = session.mood { details.append(Product22Vocabulary.text(for: mood)) }
                    details.append(Product22Vocabulary.text(for: session.visibility))

                    return Product22ListRow(
                        id: session.id.wireValue,
                        title: gameTitle ?? session.catalogGameID.wireValue,
                        subtitle: session.note,
                        details: details,
                        actionTitle: L10n.Product22.Playlog.edit
                    )
                }
            )
        )

        return sections
    }

    // MARK: Selection

    override func didSelectRow(_ row: Product22ListRow, in section: Product22ListSection) {
        guard section.id == "sessions",
              let session = sessions.first(where: { $0.id.wireValue == row.id }) else { return }
        presentActions(for: session)
    }

    private func presentActions(for session: PlaySession) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L10n.Product22.Playlog.edit, style: .default) { [weak self] _ in
            self?.presentForm(editing: session)
        })
        sheet.addAction(UIAlertAction(title: L10n.Product22.Playlog.delete, style: .destructive) { [weak self] _ in
            self?.confirmDelete(session)
        })
        sheet.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        present(sheet, animated: true)
    }

    private func confirmDelete(_ session: PlaySession) {
        let alert = UIAlertController(
            title: L10n.Product22.Playlog.deleteConfirm, message: nil, preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Product22.Playlog.delete, style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task {
                // Delete carries its own key derived from the record's, so a
                // retried delete is idempotent and cannot collide with the
                // create that wrote the row.
                try? await self.repository.delete(session)
                await MainActor.run { self.reload() }
            }
        })
        present(alert, animated: true)
    }

    private func presentForm(editing session: PlaySession?) {
        guard let catalogGameID else { return }
        let form = PlaySessionFormViewController(
            catalogGameID: catalogGameID,
            gameTitle: gameTitle,
            existing: session,
            repository: repository
        )
        form.onSaved = { [weak self] in self?.reload() }
        let navigation = UINavigationController(rootViewController: form)
        present(navigation, animated: true)
    }
}
