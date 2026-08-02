import UIKit

// MARK: - CatalogSearchViewController
//
// Canonical catalog search, and the entry point into Quick Add.
//
// The "게임이 없나요? 빠르게 등록" affordance is offered both from the empty
// result state and from the navigation bar, so a user who finds nothing does
// not have to back out to register what they were looking for.
//
// Results page in as the user scrolls, following the contract's typed
// `meta.nextCursor`. The cursor is opaque and is passed back verbatim.

final class CatalogSearchViewController: Product22ListViewController {

    private let repository: any CatalogRepositing
    private let configStore: ProductConfigStore
    private let onOpenGame: (CatalogGameID) -> Void
    private let onQuickAdd: (String?) -> Void

    private let searchController = UISearchController(searchResultsController: nil)
    private var query = ""
    private var results: [CatalogGameSummary] = []
    /// Debounces typing so a fast typist does not fire a request per keystroke.
    private var searchDebounce: Task<Void, Never>?

    init(
        repository: any CatalogRepositing,
        configStore: ProductConfigStore,
        onOpenGame: @escaping (CatalogGameID) -> Void,
        onQuickAdd: @escaping (String?) -> Void
    ) {
        self.repository = repository
        self.configStore = configStore
        self.onOpenGame = onOpenGame
        self.onQuickAdd = onQuickAdd
        super.init(nibName: nil, bundle: nil)
        title = L10n.Product22.Catalog.searchTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(repository:...)") }

    deinit { searchDebounce?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = L10n.Product22.Catalog.searchPlaceholder
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        // Second entry point, always reachable.
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.Product22.Catalog.quickAddPrompt,
            primaryAction: UIAction { [weak self] _ in
                self?.onQuickAdd(self?.currentQueryForQuickAdd())
            }
        )
    }

    /// The search text is handed to Quick Add as a starting point only. It is
    /// never stored anywhere by this screen.
    private func currentQueryForQuickAdd() -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    override func loadContent() async -> Product22ListState {
        guard await configStore.refreshIfNeeded().isEnabled(.openCatalog) else {
            return .disabled(message: L10n.Product22.Section.disabled)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return .empty(message: L10n.Product22.Catalog.searchPrompt)
        }

        do {
            let page = try await repository.search(
                query: trimmed,
                locale: Locale.current.language.languageCode?.identifier,
                regionCode: Locale.current.region?.identifier,
                platform: nil,
                cursor: nil
            )
            results = page.games
            setNextCursor(page.nextCursor)

            guard !page.games.isEmpty else {
                // `emptyQuery` and `noMatch` are different facts and the copy
                // distinguishes them: one means "we couldn't read that", the
                // other "nothing scored well enough".
                let reason = page.matchedBy == .emptyQuery
                    ? L10n.Product22.Catalog.emptyQuery
                    : L10n.Product22.Catalog.noResults
                // The empty state is where Quick Add matters most, so it names
                // the action rather than just reporting nothing found.
                return .empty(message: "\(reason)\n\(L10n.Product22.Catalog.quickAddPrompt)")
            }
            return .loaded([
                Product22ListSection(id: "results", title: nil, rows: page.games.map(Self.row(for:)))
            ])
        } catch {
            return Product22ScreenState.failure(from: error, configStore: configStore)
        }
    }

    override func loadNextPage(
        after cursor: String
    ) async -> (rows: [Product22ListRow], nextCursor: String?)? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let page = try? await repository.search(
            query: trimmed,
            locale: Locale.current.language.languageCode?.identifier,
            regionCode: Locale.current.region?.identifier,
            platform: nil,
            cursor: cursor
        ) else {
            return nil
        }
        results.append(contentsOf: page.games)
        return (page.games.map(Self.row(for:)), page.nextCursor)
    }

    static func row(for game: CatalogGameSummary) -> Product22ListRow {
        var details: [String] = []
        if let developer = game.developerName { details.append(developer) }
        // Provenance and publication status are shown, so a private or
        // unconfirmed entry never reads like a verified public one.
        details.append(Product22Vocabulary.text(for: game.titleProvenance))
        details.append(Product22Vocabulary.text(for: game.publicationStatus))
        return Product22ListRow(
            id: game.id.wireValue,
            title: game.originalTitle,     // server content
            subtitle: game.platforms.joined(separator: " · "),
            details: details,
            actionTitle: L10n.Common.Button.seeAll
        )
    }

    override func didSelectRow(_ row: Product22ListRow, in section: Product22ListSection) {
        guard let id = CatalogGameID(uuidString: row.id) else { return }
        onOpenGame(id)
    }
}

// MARK: - UISearchResultsUpdating

extension CatalogSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        query = searchController.searchBar.text ?? ""
        searchDebounce?.cancel()
        searchDebounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.reload() }
        }
    }
}
