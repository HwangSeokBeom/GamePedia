import UIKit

// MARK: - Product22SceneFactory
//
// Builds the Product 2.2 screens and pushes them onto a navigation stack.
//
// Home, Search and Library all reach parts of this surface, and none of them
// should have to know how the Product 2.2 stack is assembled. Keeping the
// wiring here means there is one place where a repository is constructed and
// one place where a route is defined, so the three coordinators cannot drift
// apart.

// Not annotated `@MainActor`: it matches the isolation of the coordinators
// that own it, which are nonisolated in this codebase and already drive UIKit
// directly. Every entry point is called from a coordinator on the main thread.
final class Product22SceneFactory {

    private let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    private func service() -> DefaultProduct22APIService {
        DefaultProduct22APIService()
    }

    private func configStore(_ service: DefaultProduct22APIService) -> ProductConfigStore {
        Product22Runtime.shared.configStore(service: service)
    }

    // MARK: Routes

    func showCatalogSearch(initialQuery: String? = nil) {
        let service = service()
        push(
            CatalogSearchViewController(
                repository: CatalogRepository(service: service),
                configStore: configStore(service),
                onOpenGame: { [weak self] id in self?.showCatalogGame(id) },
                onQuickAdd: { [weak self] query in self?.presentQuickAdd(initialQuery: query) }
            )
        )
    }

    func showCatalogGame(_ catalogGameID: CatalogGameID) {
        let service = service()
        push(
            CatalogGameViewController(
                catalogGameID: catalogGameID,
                repository: CatalogRepository(service: service),
                configStore: configStore(service),
                onOpenPlaylog: { [weak self] id, title in
                    self?.showPlaylog(catalogGameID: id, gameTitle: title)
                },
                onSuggestCorrection: { [weak self] id in self?.presentCorrection(for: id) }
            )
        )
    }

    func showPlaylog(catalogGameID: CatalogGameID?, gameTitle: String?) {
        let service = service()
        push(
            PlaylogViewController(
                catalogGameID: catalogGameID,
                gameTitle: gameTitle,
                repository: PlaylogRepository(service: service),
                configStore: configStore(service)
            )
        )
    }

    func showArticle(slug: String, card: ArticleCard?) {
        let service = service()
        push(
            ArticleReaderViewController(
                slug: slug,
                card: card,
                repository: MagazineRepository(service: service),
                onOpenCatalogGame: { [weak self] id in self?.showCatalogGame(id) }
            )
        )
    }

    func showMonthlyReplay(monthKey: String) {
        let service = service()
        push(
            MonthlyReplayViewController(
                monthKey: monthKey,
                repository: PlayIntelligenceRepository(service: service),
                configStore: configStore(service)
            )
        )
    }

    func showGameDNA() {
        let service = service()
        push(
            GameDNAViewController(
                repository: PlayIntelligenceRepository(service: service),
                configStore: configStore(service)
            )
        )
    }

    func showPlayCompass() {
        let service = service()
        push(
            PlayCompassViewController(
                repository: PlayIntelligenceRepository(service: service),
                configStore: configStore(service),
                onOpenCatalogGame: { [weak self] id in self?.showCatalogGame(id) }
            )
        )
    }

    func presentQuickAdd(initialQuery: String?) {
        let service = service()
        let viewController = QuickAddViewController(
            initialQuery: initialQuery,
            repository: QuickAddRepository(service: service),
            configStore: configStore(service),
            onFindInCatalog: { [weak self] query in self?.showCatalogSearch(initialQuery: query) },
            // Deep link straight to the game the confirmation resolved to.
            onOpenCatalogGame: { [weak self] id in self?.showCatalogGame(id) },
            onOpenSubmissionState: { [weak self] id in self?.showSubmissionState(id) }
        )
        navigationController.present(
            UINavigationController(rootViewController: viewController), animated: true
        )
    }

    func showSubmissionState(_ submissionID: CatalogSubmissionID) {
        let service = service()
        push(
            SubmissionStateViewController(
                submissionID: submissionID,
                repository: QuickAddRepository(service: service),
                configStore: configStore(service),
                onOpenCatalogGame: { [weak self] id in self?.showCatalogGame(id) }
            )
        )
    }

    /// A correction is a *proposal*, and the copy says so. The catalog view is
    /// never updated to reflect a suggested value as though it were accepted.
    func presentCorrection(for catalogGameID: CatalogGameID) {
        let alert = UIAlertController(
            title: L10n.Product22.Catalog.correction,
            message: L10n.Product22.Catalog.correctionPending,
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = L10n.Product22.Catalog.correctionFieldPath }
        alert.addTextField { $0.placeholder = L10n.Product22.Catalog.correctionValue }
        alert.addTextField {
            $0.placeholder = L10n.Product22.Catalog.correctionSource
            $0.keyboardType = .URL
        }
        alert.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Common.Button.save, style: .default) { [weak self] _ in
            guard let self,
                  let fields = alert.textFields,
                  let fieldPath = fields[0].text, !fieldPath.isEmpty,
                  let proposed = fields[1].text, !proposed.isEmpty else { return }
            // fieldPath, proposedValue and sourceUrl are the whole contract.
            // Nothing else is collected and nothing else is sent.
            let correction = CatalogCorrection(
                fieldPath: fieldPath,
                proposedValue: proposed,
                sourceURL: fields[2].text.flatMap(URL.init(string:))
            )
            let service = self.service()
            Task {
                try? await CatalogRepository(service: service)
                    .submitCorrections([correction], for: catalogGameID)
            }
        })
        navigationController.present(alert, animated: true)
    }

    // MARK: Pushing

    /// Appearance is applied before the push so the correct style is present
    /// from the first transition frame, matching the rest of the app.
    private func push(_ viewController: UIViewController) {
        NavigationBarStyler.apply(
            .opaque, to: viewController.navigationItem, buttonTintColor: .gpTextSecondary
        )
        viewController.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(viewController, animated: true)
    }
}
