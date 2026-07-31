import UIKit

// MARK: - CatalogGameViewController
//
// Canonical catalog detail: original title, localized aliases, regional
// service editions, lifecycle status and per-field provenance.
//
// Follow is optimistic and rolls back exactly on failure — the button returns
// to the state it had before the tap, not to a guessed state.

final class CatalogGameViewController: Product22ListViewController {

    private let catalogGameID: CatalogGameID
    private let repository: any CatalogRepositing
    private let configStore: ProductConfigStore

    private var detail: CatalogGameDetail?
    /// What the follow button currently claims. Diverges from `detail` only
    /// between an optimistic tap and the server's answer.
    ///
    /// `@objc dynamic` so a test can set it up without a network round trip;
    /// production code only ever reads it through `followButtonReflectsFollowing`.
    @objc private dynamic var isFollowing = false
    private var followTask: Task<Void, Never>?

    private lazy var followButton = UIBarButtonItem(
        image: UIImage(systemName: "bell"),
        primaryAction: UIAction { [weak self] _ in self?.toggleFollow() }
    )

    init(
        catalogGameID: CatalogGameID,
        repository: any CatalogRepositing,
        configStore: ProductConfigStore
    ) {
        self.catalogGameID = catalogGameID
        self.repository = repository
        self.configStore = configStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(catalogGameID:...)") }

    deinit { followTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = followButton
        followButton.isEnabled = false
    }

    override func loadContent() async -> Product22ListState {
        guard await configStore.refreshIfNeeded().isEnabled(.openCatalog) else {
            return .disabled(message: L10n.Product22.Section.disabled)
        }
        do {
            let detail = try await repository.detail(id: catalogGameID)
            self.detail = detail
            await MainActor.run {
                self.title = detail.summary.originalTitle   // server content
                self.isFollowing = detail.isFollowedByMe
                self.updateFollowButton()
                self.followButton.isEnabled = true
            }
            return .loaded(sections(for: detail))
        } catch {
            return Product22ScreenState.failure(from: error, configStore: configStore)
        }
    }

    // MARK: Follow — optimistic, with exact rollback

    @objc private func toggleFollow() {
        let previous = isFollowing
        let desired = !previous

        // Optimistic: reflect the tap immediately.
        isFollowing = desired
        updateFollowButton()

        followTask?.cancel()
        followTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.setFollowing(desired, id: catalogGameID, regionalReleaseID: nil)
            } catch {
                guard !Task.isCancelled else { return }
                let mapped = Product22ErrorMapper.map(error)
                guard !mapped.isCancellation else { return }
                await MainActor.run {
                    // Exact rollback: back to the value before the tap, not to
                    // an assumption about what the server now holds.
                    self.isFollowing = previous
                    self.updateFollowButton()
                }
            }
        }
    }

    private func updateFollowButton() {
        followButton.image = UIImage(systemName: isFollowing ? "bell.fill" : "bell")
        followButton.accessibilityLabel = isFollowing
            ? L10n.Common.Button.disconnect
            : L10n.Common.Button.connect
    }

    /// Test seam: the optimistic value the button is currently showing.
    var followButtonReflectsFollowing: Bool { isFollowing }

    // MARK: Sections

    private func sections(for detail: CatalogGameDetail) -> [Product22ListSection] {
        var sections: [Product22ListSection] = []

        // Identity, with the provenance of the title itself stated rather than
        // implied.
        var identityDetails: [String] = []
        if let developer = detail.summary.developerName { identityDetails.append(developer) }
        if let publisher = detail.summary.publisherName { identityDetails.append(publisher) }
        identityDetails.append(detail.summary.titleProvenance.rawValue)
        identityDetails.append(detail.summary.publicationStatus.rawValue)
        if detail.resolvedFromMerge {
            // The id asked for was merged into this one; say so rather than
            // silently showing a different game.
            identityDetails.append(detail.summary.id.wireValue)
        }
        sections.append(
            Product22ListSection(
                id: "identity",
                title: nil,
                rows: [
                    Product22ListRow(
                        id: detail.summary.id.wireValue,
                        title: detail.summary.originalTitle,
                        details: identityDetails
                    )
                ]
            )
        )

        // Localized aliases, kept distinct from the original title.
        let aliases = detail.aliases
        if !aliases.isEmpty {
            sections.append(
                Product22ListSection(
                    id: "aliases",
                    title: nil,
                    rows: aliases.enumerated().map { index, localization in
                        Product22ListRow(
                            id: "alias-\(index)",
                            title: localization.title,
                            details: [
                                localization.languageCode,
                                localization.regionCode,
                                localization.provenance.rawValue
                            ].compactMap { $0 }
                        )
                    }
                )
            )
        }

        // Regional service editions — where a country-specific shutdown,
        // maintenance window or pre-registration actually becomes visible.
        if !detail.regionalReleases.isEmpty {
            sections.append(
                Product22ListSection(
                    id: "regions",
                    title: nil,
                    rows: detail.regionalReleases.map { release in
                        var details = [release.serviceStatus.rawValue, release.platform]
                        if let operatorName = release.operatorName { details.append(operatorName) }
                        if let shutdown = release.shutdownDate { details.append(shutdown) }
                        details.append(release.provenance.rawValue)
                        return Product22ListRow(
                            id: release.id.wireValue,
                            title: release.countryCode,
                            details: details
                        )
                    }
                )
            )
        }

        // Per-field evidence, so an inferred value never looks confirmed.
        if !detail.fieldEvidence.isEmpty {
            sections.append(
                Product22ListSection(
                    id: "evidence",
                    title: nil,
                    rows: detail.fieldEvidence.map { evidence in
                        Product22ListRow(
                            id: evidence.fieldPath,
                            title: evidence.fieldPath,
                            details: [evidence.provenance.rawValue, evidence.sourceType]
                        )
                    }
                )
            )
        }

        return sections
    }
}
