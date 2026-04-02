import UIKit

final class LibraryViewController: BaseViewController<LibraryRootView, LibraryState> {
    private struct SectionScopedItem: Hashable {
        let section: LibrarySectionKind
        let item: LibraryCollectionItem
    }

    private let viewModel: LibraryViewModel
    private var dataSource: UICollectionViewDiffableDataSource<LibrarySectionKind, SectionScopedItem>!
    private var currentSections: [LibrarySectionViewState] = []
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?
    private var lastPresentedSteamOnboarding: LibraryOnboardingViewState?
    private let refreshControl = UIRefreshControl()
    private var toastHideWorkItem: DispatchWorkItem?
    private weak var toastView: LibraryToastView?
    private var summaryLoadStartedAt: CFTimeInterval?
    private var didLogFirstSnapshotApplyForCurrentLoad = false
    private var wasSummaryLoading = false

    var onGameSelected: ((Int) -> Void)?
    var onSteamDetailRequested: ((SteamFallbackGameDetailViewState) -> Void)?
    var onSteamLinkRequested: ((URL) -> Void)?
    var onSteamPrivacyGuideRequested: ((URL) -> Void)?
    var onSectionListRequested: ((LibrarySectionListRoute) -> Void)?

    init(
        rootView: LibraryRootView = LibraryRootView(),
        viewModel: LibraryViewModel = LibraryViewModel()
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[Library] viewDidLoad")
        setupCollectionView()
        setupBindings()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("[Library] viewWillAppear refreshExecuted=false snapshotReapplyPending=false")
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func render(_ state: LibraryState) {
        if state.isSummaryLoading, !wasSummaryLoading {
            summaryLoadStartedAt = CACurrentMediaTime()
            didLogFirstSnapshotApplyForCurrentLoad = false
        }

        let summaryBecameReady = wasSummaryLoading && !state.isSummaryLoading
        rootView.render(state)

        if summaryBecameReady, let summaryLoadStartedAt {
            let elapsedMilliseconds = Int((CACurrentMediaTime() - summaryLoadStartedAt) * 1000)
            let summarySource = state.summaryByTab[state.selectedTab]?.sourceDescription ?? "nil"
            print(
                "[LibraryPerformance] " +
                "timeToFirstSummaryRenderMs=\(elapsedMilliseconds) " +
                "selectedTab=\(state.selectedTab) " +
                "summarySource=\(summarySource) " +
                "waitedForSnapshot=false"
            )
        }

        applySnapshot(sections: state.sections, focusedSection: state.pendingFocusSection)

        if !state.isRefreshing {
            refreshControl.endRefreshing()
        }

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            let alert = UIAlertController(title: L10n.Common.Error.title, message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
            present(alert, animated: true)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }

        if let successMessage = state.successMessage,
           successMessage != lastPresentedSuccessMessage {
            lastPresentedSuccessMessage = successMessage
            showToast(message: successMessage)
            viewModel.send(.didConsumeSuccessMessage)
        } else if state.successMessage == nil {
            lastPresentedSuccessMessage = nil
        }

        if let onboarding = state.steamConnectionOnboarding,
           onboarding != lastPresentedSteamOnboarding {
            lastPresentedSteamOnboarding = onboarding
            presentSteamConnectionOnboardingAlert(onboarding)
        } else if state.steamConnectionOnboarding == nil {
            lastPresentedSteamOnboarding = nil
        }

        updateNavigationItems(with: state)
        wasSummaryLoading = state.isSummaryLoading
    }

    func retrySteamPrivacyGuidance() {
        viewModel.send(.retrySteamPrivacyGuideTapped)
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = L10n.Library.Navigation.title
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    private func setupCollectionView() {
        rootView.setCollectionViewLayout(makeLayout())
        rootView.collectionView.delegate = self
        rootView.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        rootView.collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        rootView.collectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)

        rootView.collectionView.register(LibraryGameCardCell.self, forCellWithReuseIdentifier: LibraryGameCardCell.reuseId)
        rootView.collectionView.register(LibraryGameRowCell.self, forCellWithReuseIdentifier: LibraryGameRowCell.reuseId)
        rootView.collectionView.register(LibraryInfoCell.self, forCellWithReuseIdentifier: LibraryInfoCell.reuseId)
        rootView.collectionView.register(
            LibrarySectionHeaderReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: LibrarySectionHeaderReusableView.reuseId
        )

        dataSource = UICollectionViewDiffableDataSource<LibrarySectionKind, SectionScopedItem>(
            collectionView: rootView.collectionView
        ) { [weak self] collectionView, indexPath, scopedItem in
            guard let self else { return UICollectionViewCell() }
            let item = scopedItem.item

            switch item {
            case .recentCard(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryGameCardCell.reuseId,
                    for: indexPath
                ) as! LibraryGameCardCell
                cell.configure(with: viewState)
                cell.onActionButtonTapped = { [weak self] in
                    self?.viewModel.send(
                        .didTapAddToPlaying(gameID: viewState.identifier, source: viewState.identifier.source)
                    )
                }
                return cell

            case .row(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryGameRowCell.reuseId,
                    for: indexPath
                ) as! LibraryGameRowCell
                cell.configure(with: viewState)
                cell.onTrailingActionTapped = { [weak self] in
                    guard viewState.trailingAction == .removeWishlist else { return }
                    self?.presentRemoveFavoriteAlert(identifier: viewState.identifier, title: viewState.title)
                }
                return cell

            case .message(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryInfoCell.reuseId,
                    for: indexPath
                ) as! LibraryInfoCell
                cell.configure(with: viewState)
                cell.onButtonTapped = { [weak self] in
                    guard let action = viewState.action else { return }
                    switch action {
                    case .connectSteam:
                        self?.viewModel.send(.connectSteamButtonTapped)
                    case .showSteamPrivacyGuide:
                        self?.viewModel.send(.steamPrivacyGuideButtonTapped)
                    case .retrySteamSync:
                        self?.viewModel.send(.retrySteamSyncTapped)
                    case .retryOwnedSteamSync:
                        self?.viewModel.send(.syncOwnedSteamLibraryButtonTapped)
                    case .retryPlaytimeRecommendations:
                        self?.viewModel.send(.retryPlaytimeRecommendationsTapped)
                    case .retryFriendRecommendations:
                        self?.viewModel.send(.retryFriendRecommendationsTapped)
                    }
                }
                return cell
            }
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self,
                  kind == UICollectionView.elementKindSectionHeader,
                  indexPath.section < self.currentSections.count else {
                return nil
            }

            let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: LibrarySectionHeaderReusableView.reuseId,
                for: indexPath
            ) as! LibrarySectionHeaderReusableView

            let section = self.currentSections[indexPath.section]
            headerView.configure(
                sectionKind: section.kind,
                showsSeeMore: section.showsSeeAll
            )
            headerView.onSeeMoreTapped = { [weak self] in
                guard let self else { return }
                switch section.kind {
                case .recentlyPlayed:
                    self.viewModel.send(.didTapSeeAllRecentlyPlayed)
                case .playing:
                    self.viewModel.send(.didTapSeeAllPlaying)
                case .owned:
                    self.viewModel.send(.didTapSeeAllOwned)
                case .playtimeRecommendations:
                    self.viewModel.send(.didTapSeeAllPlaytimeRecommendations)
                case .friendRecommendations:
                    self.viewModel.send(.didTapSeeAllFriendRecommendations)
                case .reviewed:
                    self.viewModel.send(.didTapSeeAllReviewed)
                case .wishlist:
                    self.viewModel.send(.didTapSeeAllWishlist)
                }
            }
            return headerView
        }
    }

    private func setupBindings() {
        rootView.onPrimaryTabSelected = { [weak self] index in
            self?.viewModel.send(.didSelectPrimaryTab(index))
        }
        rootView.onFilterSelected = { [weak self] index in
            self?.viewModel.send(.didSelectHighlightChip(index))
        }
        rootView.onSteamPrimaryActionTapped = { [weak self] in
            guard let self else { return }
            if self.viewModel.state.isSteamConnected {
                self.viewModel.send(.syncOwnedSteamLibraryButtonTapped)
            } else {
                self.viewModel.send(.connectSteamButtonTapped)
            }
        }
        rootView.onSteamSecondaryActionTapped = { [weak self] in
            self?.presentSteamUnlinkConfirmationAlert()
        }
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }

        viewModel.onRoute = { [weak self] route in
            switch route {
            case .showGameDetail(let gameID):
                self?.onGameSelected?(gameID)
            case .showSteamDetail(let viewState):
                self?.onSteamDetailRequested?(viewState)
            case .showSteamLink(let url):
                self?.onSteamLinkRequested?(url)
            case .showSteamPrivacyGuide(let url):
                self?.onSteamPrivacyGuideRequested?(url)
            case .showSectionList(let route):
                self?.onSectionListRequested?(route)
            case .showReviewed:
                break
            }
        }
    }

    private func applySnapshot(sections: [LibrarySectionViewState], focusedSection: LibrarySectionKind?) {
        let sanitizedSections = sanitizeSectionsForSnapshot(sections)
        if sanitizedSections == currentSections {
            print(
                "[LibrarySnapshot] applySkipped reason=unchanged " +
                "sectionCounts=\(sanitizedSections.map { "\($0.kind)=\($0.items.count)" }.joined(separator: ","))"
            )
            scrollToFocusedSectionIfNeeded(focusedSection)
            return
        }
        currentSections = sanitizedSections

        var snapshot = NSDiffableDataSourceSnapshot<LibrarySectionKind, SectionScopedItem>()
        let sectionKinds = sanitizedSections.map(\.kind)
        snapshot.appendSections(sectionKinds)

        for section in sanitizedSections {
            let scopedItems = section.items.map { SectionScopedItem(section: section.kind, item: $0) }
            snapshot.appendItems(scopedItems, toSection: section.kind)
        }

        print(
            "[LibrarySnapshot] applyPerformed " +
            "sectionCounts=\(sanitizedSections.map { "\($0.kind)=\($0.items.count)" }.joined(separator: ","))"
        )

        if let summaryLoadStartedAt, !didLogFirstSnapshotApplyForCurrentLoad {
            let elapsedMilliseconds = Int((CACurrentMediaTime() - summaryLoadStartedAt) * 1000)
            print(
                "[LibraryPerformance] " +
                "timeToFirstSnapshotApplyMs=\(elapsedMilliseconds) " +
                "sectionCount=\(sanitizedSections.count)"
            )
            didLogFirstSnapshotApplyForCurrentLoad = true
        }

        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            self.rootView.collectionView.collectionViewLayout.invalidateLayout()
            self.scrollToFocusedSectionIfNeeded(focusedSection)
        }
    }

    private func scrollToFocusedSectionIfNeeded(_ focusedSection: LibrarySectionKind?) {
        guard let focusedSection,
              let sectionIndex = currentSections.firstIndex(where: { $0.kind == focusedSection }),
              let firstItem = currentSections[sectionIndex].items.first else {
            return
        }

        let indexPath = IndexPath(item: 0, section: sectionIndex)
        guard dataSource.itemIdentifier(for: indexPath)?.item == firstItem else { return }
        rootView.collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
        viewModel.send(.didConsumeInitialFocus)
    }

    private func presentRemoveFavoriteAlert(identifier: LibraryGameIdentifier, title: String) {
        let alert = UIAlertController(
            title: L10n.Library.Alert.removeFavoriteTitle,
            message: L10n.Library.Alert.removeFavoriteMessage(title),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Common.Button.delete, style: .destructive) { [weak self] _ in
            self?.viewModel.send(.didConfirmRemoveFavorite(identifier))
        })
        present(alert, animated: true)
    }

    @objc
    private func didPullToRefresh() {
        print("[Library] pullToRefresh")
        viewModel.send(.pullToRefresh)
    }

    private func updateNavigationItems(with state: LibraryState) {
        navigationItem.rightBarButtonItems = nil
    }

    private func sanitizeSectionsForSnapshot(_ sections: [LibrarySectionViewState]) -> [LibrarySectionViewState] {
        var seenKinds = Set<LibrarySectionKind>()
        return sections.compactMap { section in
            guard seenKinds.insert(section.kind).inserted else {
                print("[LibrarySnapshot] droppedDuplicateSection kind=\(section.kind)")
                return nil
            }

            let beforeCount = section.items.count
            var seenItems = Set<LibraryCollectionItem>()
            let deduplicatedItems = section.items.filter { item in
                let inserted = seenItems.insert(item).inserted
                if !inserted {
                    print("[LibrarySnapshot] droppedDuplicateItem section=\(section.kind) item=\(item)")
                }
                return inserted
            }
            print(
                "[LibrarySnapshot] " +
                "section=\(section.kind) " +
                "itemCountBeforeDedupe=\(beforeCount) " +
                "itemCountAfterDedupe=\(deduplicatedItems.count) " +
                "duplicatesRemoved=\(beforeCount - deduplicatedItems.count > 0) " +
                "dedupeScope=sectionLocal"
            )

            return LibrarySectionViewState(
                kind: section.kind,
                layoutStyle: section.layoutStyle,
                items: deduplicatedItems,
                showsSeeAll: section.showsSeeAll
            )
        }
    }

    private func presentSteamUnlinkConfirmationAlert() {
        let alert = UIAlertController(
            title: L10n.Profile.Alert.steamUnlinkTitle,
            message: L10n.Profile.Alert.steamUnlinkMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Library.Steam.Button.disconnect, style: .destructive) { [weak self] _ in
            self?.viewModel.send(.unlinkSteamConfirmed)
        })
        present(alert, animated: true)
    }

    private func presentSteamConnectionOnboardingAlert(_ onboarding: LibraryOnboardingViewState) {
        let messageComponents = [onboarding.message, onboarding.helperText].compactMap { $0 }
        let alert = UIAlertController(
            title: onboarding.title,
            message: messageComponents.joined(separator: "\n\n"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default) { [weak self] _ in
            self?.viewModel.send(.didConsumeSteamConnectionOnboarding)
        })
        present(alert, animated: true)
    }

    private func showToast(message: String) {
        toastHideWorkItem?.cancel()
        toastView?.removeFromSuperview()

        let toastView = LibraryToastView(message: message)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.alpha = 0
        view.addSubview(toastView)
        self.toastView = toastView

        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -20
            ),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])

        UIView.animate(withDuration: 0.2) {
            toastView.alpha = 1
        }

        let hideWorkItem = DispatchWorkItem { [weak toastView] in
            UIView.animate(withDuration: 0.2, animations: {
                toastView?.alpha = 0
            }, completion: { _ in
                toastView?.removeFromSuperview()
            })
        }
        toastHideWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: hideWorkItem)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self, sectionIndex < self.currentSections.count else { return nil }
            let section = self.currentSections[sectionIndex]

            let sectionLayout: NSCollectionLayoutSection
            switch section.layoutStyle {
            case .recentCards:
                sectionLayout = self.makeRecentCardsSection()
            case .list:
                sectionLayout = self.makeListSection(containerWidth: environment.container.effectiveContentSize.width)
            case .message:
                sectionLayout = self.makeMessageSection(containerWidth: environment.container.effectiveContentSize.width)
            }

            sectionLayout.boundarySupplementaryItems = [self.makeHeaderBoundaryItem()]
            return sectionLayout
        }
    }

    private func makeRecentCardsSection() -> NSCollectionLayoutSection {
        let itemInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .estimated(250)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = itemInsets
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(250)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
        group.interItemSpacing = .fixed(12)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        return section
    }

    private func makeListSection(containerWidth: CGFloat) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(92)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(containerWidth - 32),
            heightDimension: .estimated(92)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 20, trailing: 16)
        return section
    }

    private func makeMessageSection(containerWidth: CGFloat) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(116)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(containerWidth - 32),
            heightDimension: .estimated(116)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 18, trailing: 16)
        return section
    }

    private func makeHeaderBoundaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(54)
            ),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}

extension LibraryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section < currentSections.count,
              let item = dataSource.itemIdentifier(for: indexPath)?.item else {
            return
        }

        let section = currentSections[indexPath.section]

        switch item {
        case .recentCard(let viewState):
            switch viewState.detailDestination {
            case .igdb(let gameID):
                print(
                    "[GameTap] screen=Library.overview.\(section.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=igdb:\(gameID) " +
                    "igdbGameId=\(gameID) " +
                    "externalGameId=\(viewState.identifier.sourceID)"
                )
            case .steamFallback(let steamViewState):
                print(
                    "[GameTap] screen=Library.overview.\(section.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=steamFallback " +
                    "igdbGameId=nil " +
                    "externalGameId=\(steamViewState.externalGameId)"
                )
            case .none:
                print(
                    "[GameTap] screen=Library.overview.\(section.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=nil " +
                    "igdbGameId=nil " +
                    "externalGameId=\(viewState.identifier.sourceID)"
                )
            }
            viewModel.send(.didTapRecentlyPlayedGame(viewState.identifier))
        case .row(let viewState):
            switch viewState.detailDestination {
            case .igdb(let gameID):
                print(
                    "[GameTap] screen=Library.overview.\(section.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=igdb:\(gameID) " +
                    "igdbGameId=\(gameID) " +
                    "externalGameId=\(viewState.identifier.sourceID)"
                )
            case .steamFallback(let steamViewState):
                print(
                    "[GameTap] screen=Library.overview.\(section.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=steamFallback " +
                    "igdbGameId=nil " +
                    "externalGameId=\(steamViewState.externalGameId)"
                )
            case .none:
                print(
                    "[GameTap] screen=Library.overview.\(section.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=nil " +
                    "igdbGameId=nil " +
                    "externalGameId=\(viewState.identifier.sourceID)"
                )
            }
            switch section.kind {
            case .playing:
                viewModel.send(.didTapPlayingGame(viewState.identifier))
            case .owned:
                viewModel.send(.didTapPlayingGame(viewState.identifier))
            case .playtimeRecommendations:
                viewModel.send(.didTapPlaytimeRecommendationGame(viewState.identifier))
            case .friendRecommendations:
                viewModel.send(.didTapFriendRecommendationGame(viewState.identifier))
            case .wishlist:
                viewModel.send(.didTapWishlistGame(viewState.identifier))
            case .reviewed:
                viewModel.send(.didTapReviewedGame(viewState.identifier))
            case .recentlyPlayed:
                break
            }
        case .message:
            break
        }
    }
}

private final class LibrarySectionHeaderReusableView: UICollectionReusableView {
    static let reuseId = "LibrarySectionHeaderReusableView"

    var onSeeMoreTapped: (() -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let seeMoreButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = L10n.Common.Button.seeAll
        config.baseForegroundColor = .gpPrimary
        config.contentInsets = .zero
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    private let titleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(sectionKind: LibrarySectionKind, showsSeeMore: Bool) {
        titleLabel.text = sectionKind.title
        subtitleLabel.text = sectionKind.subtitle
        subtitleLabel.isHidden = sectionKind.subtitle == nil
        seeMoreButton.isHidden = !showsSeeMore
    }

    private func setup() {
        [titleLabel, subtitleLabel].forEach { titleStackView.addArrangedSubview($0) }
        let containerStackView = UIStackView(arrangedSubviews: [titleStackView, UIView(), seeMoreButton])
        containerStackView.axis = .horizontal
        containerStackView.alignment = .top
        containerStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerStackView)
        seeMoreButton.addTarget(self, action: #selector(didTapSeeMore), for: .touchUpInside)

        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: topAnchor),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc
    private func didTapSeeMore() {
        onSeeMoreTapped?()
    }
}

private final class LibraryToastView: UIView {
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(message: String) {
        super.init(frame: .zero)
        messageLabel.text = message
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = UIColor.gpSurface.withAlphaComponent(0.96)
        layer.cornerRadius = 14
        layer.masksToBounds = true

        addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}
