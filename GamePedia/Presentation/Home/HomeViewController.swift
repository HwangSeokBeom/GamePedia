import UIKit

// MARK: - HomeViewController

final class HomeViewController: BaseViewController<HomeRootView, HomeState> {

    private enum SkeletonItemCount {
        static let todayRecommendation = 2
        static let popular = 4
        static let trending = 3
    }

    // MARK: Properties
    private let viewModel: HomeViewModel
    private var dataSource: UICollectionViewDiffableDataSource<HomeRootView.Section, HomeCollectionItem>!
    private var isShowingSkeletonSnapshot = false
    private var lastRenderedWishlistedGameIDs = Set<Int>()
    private let filterButton = HomeNavigationIconButton(systemImageName: "gamecontroller.fill")
    private let notificationButton = HomeNavigationIconButton(systemImageName: "bell")

    // Set by HomeCoordinator — called when the user taps a game cell.
    var onGameSelected: ((Int) -> Void)?
    var onRoute: ((HomeRoute) -> Void)?
    private var firstRenderMetricToken: MetricIntervalToken?

    // MARK: Init
    init(
        rootView: HomeRootView,
        viewModel: HomeViewModel = HomeViewModel()
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        configureNavigationItem()
    }

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        firstRenderMetricToken = AppObservability.shared.recorder.begin(.firstHomeRender)
        setupDataSource()
        bindViewModel()
        setupSearchHintAction()
        setupHighlightSelection()
        viewModel.send(.viewDidLoad)
    }

    // MARK: - Navigation Bar

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            applyTitleAppearance()
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.titleView = nil
            navigationItem.title = L10n.App.name
            navigationItem.leftBarButtonItem = makeFilterItem()
            navigationItem.rightBarButtonItem = makeNotificationItem()
        }
    }

    private func makeFilterItem() -> UIBarButtonItem {
        filterButton.addTarget(self, action: #selector(didTapHomeFilter), for: .touchUpInside)
        return UIBarButtonItem(customView: filterButton)
    }

    private func makeNotificationItem() -> UIBarButtonItem {
        notificationButton.addTarget(self, action: #selector(didTapNotification), for: .touchUpInside)
        return UIBarButtonItem(customView: notificationButton)
    }

    private func applyTitleAppearance() {
        let appearance = navigationItem.standardAppearance?.copy() as? UINavigationBarAppearance
            ?? UINavigationBarAppearance()
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline)
        let titleFont = UIFont(descriptor: descriptor, size: 22)

        appearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.gpTextPrimary,
            NSAttributedString.Key.font: titleFont
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }

    private func setupSearchHintAction() {
        rootView.onSearchTapped = { [weak self] in
            self?.tabBarController?.selectedIndex = 1
        }
    }

    private func setupHighlightSelection() {
        rootView.highlightCarouselView.onHighlightSelected = { [weak self] highlight in
            GameDetailSeedStore.shared.store(games: [highlight.game], screen: "Home.highlightTap")
            self?.viewModel.send(.didTapGame(highlight.game))
            self?.onGameSelected?(highlight.game.id)
        }
    }

    // MARK: - DataSource

    private func setupDataSource() {
        let cv = rootView.collectionView
        cv.delegate = self

        dataSource = UICollectionViewDiffableDataSource<HomeRootView.Section, HomeCollectionItem>(
            collectionView: cv
        ) { [weak self] collectionView, indexPath, item in
            guard let self else { return UICollectionViewCell() }
            return self.cellProvider(collectionView: collectionView, indexPath: indexPath, item: item)
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else { return nil }
            return self.headerProvider(collectionView: collectionView, kind: kind, indexPath: indexPath)
        }

        // Both the layout and the header provider resolve a section by its
        // identifier rather than its position, so the server can decide how
        // many Today sections there are and in what order.
        rootView.sectionIdentifierProvider = { [weak self] index in
            self?.dataSource.sectionIdentifier(for: index)
        }
    }

    private func cellProvider(
        collectionView: UICollectionView,
        indexPath: IndexPath,
        item: HomeCollectionItem
    ) -> UICollectionViewCell {
        switch item {
        case .todayNotice(let message):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TodayNoticeCell.reuseId, for: indexPath
            ) as! TodayNoticeCell
            cell.configure(message: message)
            return cell

        case .todayItem(_, let todayItem):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TodayItemCell.reuseId, for: indexPath
            ) as! TodayItemCell
            cell.configure(with: todayItem)
            return cell

        case .todayStatus(let key, let message, let retryTitle):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TodayStatusCell.reuseId, for: indexPath
            ) as! TodayStatusCell
            // A disabled section has no retry title and therefore no action —
            // a kill switch cannot be retried.
            cell.configure(
                message: message,
                retryTitle: retryTitle,
                onRetry: retryTitle == nil ? nil : { [weak self] in
                    self?.viewModel.send(.retryTodaySection(key))
                }
            )
            return cell

        case .todaySkeleton:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TodayStatusCell.reuseId, for: indexPath
            ) as! TodayStatusCell
            cell.configure(message: L10n.Common.State.loading, retryTitle: nil, onRetry: nil)
            return cell

        case .todayRecommendation(let recommendation):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TodayRecommendationCardCell.reuseId, for: indexPath
            ) as! TodayRecommendationCardCell
            let resolvedTitle = viewModel.state.resolvedTitle(for: recommendation.game)
            cell.configure(with: recommendation, resolvedTitle: resolvedTitle)
            return cell

        case .popular(let game):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: GameHorizontalCell.reuseId, for: indexPath
            ) as! GameHorizontalCell
            let resolvedTitle = viewModel.state.resolvedTitle(for: game)
            cell.configure(with: game, resolvedTitle: resolvedTitle)
            return cell

        case .trending(let game):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: GameRowCell.reuseId, for: indexPath
            ) as! GameRowCell
            let resolvedTitle = viewModel.state.resolvedTitle(for: game)
            cell.configure(
                with: game,
                resolvedTitle: resolvedTitle,
                isWishlisted: viewModel.state.wishlistedGameIDs.contains(game.id),
                showLikeButton: false
            )
            cell.onFavoriteButtonTapped = { [weak self] in
                self?.viewModel.send(.didTapFavorite(gameId: game.id))
            }
            return cell

        case .todayRecommendationSkeleton:
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: TodayRecommendationSkeletonCell.reuseId,
                for: indexPath
            )

        case .popularSkeleton:
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: GameHorizontalSkeletonCell.reuseId,
                for: indexPath
            )

        case .trendingSkeleton:
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: GameRowSkeletonCell.reuseId,
                for: indexPath
            )
        }
    }

    private func headerProvider(
        collectionView: UICollectionView,
        kind: String,
        indexPath: IndexPath
    ) -> UICollectionReusableView? {
        guard kind == UICollectionView.elementKindSectionHeader else { return nil }
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: HomeSectionHeaderView.reuseId,
            for: indexPath
        ) as! HomeSectionHeaderView
        header.sectionHeader.seeMoreButton.removeTarget(nil, action: nil, for: .touchUpInside)

        guard let section = dataSource.sectionIdentifier(for: indexPath.section) else {
            header.configure(title: "", systemImageName: nil, tintColor: .gpTextPrimary, showSeeMore: false)
            return header
        }

        configureHeader(header, for: section, showsSkeleton: viewModel.state.showsSkeleton)
        return header
    }

    private func configureHeader(
        _ header: HomeSectionHeaderView,
        for section: HomeRootView.Section,
        showsSkeleton: Bool
    ) {
        if showsSkeleton {
            header.configureSkeleton()
            return
        }

        switch section {
        case .todayNotice:
            // Notices carry their own copy in the cell and need no header.
            header.configure(title: "", systemImageName: nil, tintColor: .gpTextPrimary, showSeeMore: false)

        case .today(let key):
            // The title comes from the Today display model, which is the one
            // place that maps a server section key to localized copy.
            header.configure(
                title: TodayDisplayModel.title(for: key),
                systemImageName: nil,
                tintColor: .gpPrimary,
                showSeeMore: false
            )

        case .todayRecommendation:
            header.configure(
                title: HomeSection.todayRecommendation.headerTitle,
                systemImageName: HomeSection.todayRecommendation.systemImageName,
                tintColor: .gpPrimary
            )
            header.sectionHeader.seeMoreButton.addTarget(self, action: #selector(didTapTodayRecommendationSeeMore), for: .touchUpInside)
        case .popular:
            header.configure(
                title: HomeSection.popular.headerTitle,
                systemImageName: HomeSection.popular.systemImageName,
                tintColor: .gpStar
            )
            header.sectionHeader.seeMoreButton.addTarget(self, action: #selector(didTapPopularSeeMore), for: .touchUpInside)
        case .trending:
            header.configure(
                title: HomeSection.trending.headerTitle,
                systemImageName: HomeSection.trending.systemImageName,
                tintColor: .gpBadge
            )
            header.sectionHeader.seeMoreButton.addTarget(self, action: #selector(didTapTrendingSeeMore), for: .touchUpInside)
        }
    }

    // MARK: - ViewModel Binding

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
        viewModel.onRoute = { [weak self] route in
            self?.handle(route)
        }
    }

    override func render(_ state: HomeState) {
        completeFirstRenderMetricIfNeeded(state: state)
        GameDetailSeedStore.shared.store(
            games: Array(
                Set(
                    state.highlights.map(\.game) +
                    state.todayRecommendations.map(\.game) +
                    state.popularGames +
                    state.trendingGames
                )
            ),
            screen: "Home.render"
        )
        filterButton.setTintColor(state.hasActiveFilters ? .gpPrimary : .gpTextSecondary)
        notificationButton.setBadgeVisible(state.unreadNotificationCount > 0)
        rootView.setHighlightLoadingVisible(state.showsSkeleton)

        if state.showsSkeleton {
            rootView.setHighlightsVisible(false)
        } else {
            rootView.highlightCarouselView.update(with: state.resolvedHighlights)
            rootView.setHighlightsVisible(!state.highlights.isEmpty)
        }

        applySnapshot(state: state)
    }

    // Ends the first-render interval on the first render that shows real
    // content (skeleton dismissed with at least one populated section).
    private func completeFirstRenderMetricIfNeeded(state: HomeState) {
        guard let token = firstRenderMetricToken, !state.showsSkeleton else { return }
        let hasContent = !state.highlights.isEmpty
            || !state.todayRecommendations.isEmpty
            || !state.popularGames.isEmpty
            || !state.trendingGames.isEmpty
        guard hasContent else { return }
        firstRenderMetricToken = nil
        AppObservability.shared.recorder.end(token, outcome: .success)
        AppObservability.shared.markFirstMeaningfulRenderIfNeeded()
    }

    private func handle(_ route: HomeRoute) {
        switch route {
        case .presentHomeFilterSheet(let filter):
            presentHomeFilterSheet(filter: filter)
        case .showGameList, .showNotifications,
             .showCatalogGame, .showArticle, .showMonthlyReplay,
             .showGameDNA, .showPlayCompass:
            // Product 2.2 destinations are owned by HomeCoordinator, which is
            // the only place that knows how to build them.
            onRoute?(route)
        }
    }

    private func presentHomeFilterSheet(filter: HomeContentFilter) {
        let viewController = HomeFilterSheetViewController(filter: filter)
        viewController.onApply = { [weak self] updatedFilter in
            self?.viewModel.send(.didTapApplyHomeFilters(updatedFilter))
        }
        present(viewController, animated: true)
    }

    private func applySnapshot(state: HomeState) {
        var snapshot = NSDiffableDataSourceSnapshot<HomeRootView.Section, HomeCollectionItem>()
        appendTodaySections(state: state, snapshot: &snapshot)
        snapshot.appendSections(HomeRootView.Section.legacyDiscovery)
        let isFavoriteStateOnlyUpdate = !state.showsSkeleton
            && dataSource.snapshot().numberOfItems > 0
            && lastRenderedWishlistedGameIDs != state.wishlistedGameIDs

        if state.showsSkeleton {
            snapshot.appendItems(
                (0..<SkeletonItemCount.todayRecommendation).map { .todayRecommendationSkeleton($0) },
                toSection: .todayRecommendation
            )
            snapshot.appendItems(
                (0..<SkeletonItemCount.popular).map { .popularSkeleton($0) },
                toSection: .popular
            )
            snapshot.appendItems(
                (0..<SkeletonItemCount.trending).map { .trendingSkeleton($0) },
                toSection: .trending
            )
        } else {
            snapshot.appendItems(
                state.todayRecommendations.map { .todayRecommendation($0) },
                toSection: .todayRecommendation
            )
            snapshot.appendItems(state.popularGames.map { .popular($0) }, toSection: .popular)
            snapshot.appendItems(state.trendingGames.map { .trending($0) }, toSection: .trending)
            reconfigureTrendingItemsIfNeeded(state: state, snapshot: &snapshot)
        }

        let shouldAnimateDifferences = !state.showsSkeleton
            && !isShowingSkeletonSnapshot
            && dataSource.snapshot().numberOfItems > 0

        dataSource.apply(snapshot, animatingDifferences: shouldAnimateDifferences && !isFavoriteStateOnlyUpdate) { [weak self] in
            self?.refreshVisibleSectionHeaders(showsSkeleton: state.showsSkeleton)
        }
        isShowingSkeletonSnapshot = state.showsSkeleton
        lastRenderedWishlistedGameIDs = state.wishlistedGameIDs
    }

    /// Appends the Product 2.2 Today sections above the legacy discovery
    /// sections, in the order the server chose.
    ///
    /// Nothing is appended when Today is absent — the feature is off, nobody
    /// is signed in, or it has not loaded — so Home falls back to exactly the
    /// experience it had before Product 2.2 existed.
    private func appendTodaySections(
        state: HomeState,
        snapshot: inout NSDiffableDataSourceSnapshot<HomeRootView.Section, HomeCollectionItem>
    ) {
        if state.showsTodaySkeleton {
            snapshot.appendSections([.today(.playCompass)])
            snapshot.appendItems(
                [.todaySkeleton(key: .playCompass, index: 0)],
                toSection: .today(.playCompass)
            )
            return
        }

        guard let today = state.today else { return }

        var notices: [HomeCollectionItem] = []
        if today.isStale { notices.append(.todayNotice(message: L10n.Product22.Today.stale)) }
        if today.showsPartialFailureNotice {
            notices.append(.todayNotice(message: L10n.Product22.Today.partialNotice))
        }
        if !notices.isEmpty {
            snapshot.appendSections([.todayNotice])
            snapshot.appendItems(notices, toSection: .todayNotice)
        }

        for section in today.sections {
            let identifier = HomeRootView.Section.today(section.key)
            snapshot.appendSections([identifier])

            switch section.state {
            case .items(let items):
                snapshot.appendItems(
                    items.map { .todayItem(key: section.key, item: $0) },
                    toSection: identifier
                )
            case .empty(let message):
                snapshot.appendItems(
                    [.todayStatus(key: section.key, message: message, retryTitle: nil)],
                    toSection: identifier
                )
            case .disabled(let message):
                // No retry title: a kill switch cannot be retried.
                snapshot.appendItems(
                    [.todayStatus(key: section.key, message: message, retryTitle: nil)],
                    toSection: identifier
                )
            case .unavailable(let message, let retryTitle):
                let isRetrying = state.retryingTodaySections.contains(section.key)
                snapshot.appendItems(
                    [.todayStatus(
                        key: section.key,
                        message: isRetrying ? L10n.Common.State.loading : message,
                        retryTitle: isRetrying ? nil : retryTitle
                    )],
                    toSection: identifier
                )
            }
        }
    }

    private func reconfigureTrendingItemsIfNeeded(
        state: HomeState,
        snapshot: inout NSDiffableDataSourceSnapshot<HomeRootView.Section, HomeCollectionItem>
    ) {
        guard dataSource.snapshot().numberOfItems > 0,
              lastRenderedWishlistedGameIDs != state.wishlistedGameIDs else {
            return
        }

        let changedGameIDs = lastRenderedWishlistedGameIDs.symmetricDifference(state.wishlistedGameIDs)
        let itemsToRefresh = state.trendingGames
            .filter { changedGameIDs.contains($0.id) }
            .map { HomeCollectionItem.trending($0) }

        guard !itemsToRefresh.isEmpty else { return }

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(itemsToRefresh)
        } else {
            snapshot.reloadItems(itemsToRefresh)
        }
    }

    private func refreshVisibleSectionHeaders(showsSkeleton: Bool) {
        // Driven by what is actually on screen, because the section list is no
        // longer a fixed set known at compile time.
        for (index, section) in dataSource.snapshot().sectionIdentifiers.enumerated() {
            let indexPath = IndexPath(item: 0, section: index)
            guard let header = rootView.collectionView.supplementaryView(
                forElementKind: UICollectionView.elementKindSectionHeader,
                at: indexPath
            ) as? HomeSectionHeaderView else {
                continue
            }
            header.sectionHeader.seeMoreButton.removeTarget(nil, action: nil, for: .touchUpInside)
            configureHeader(header, for: section, showsSkeleton: showsSkeleton)
        }
    }

    // MARK: - Actions

    @objc private func didTapNotification() {
        viewModel.send(.didTapNotification)
    }

    @objc private func didTapHomeFilter() {
        viewModel.send(.didTapHomeFilter)
    }

    @objc private func didTapTodayRecommendationSeeMore() {
        viewModel.send(.didTapSeeMore(section: .todayRecommendation))
    }

    @objc private func didTapPopularSeeMore() {
        viewModel.send(.didTapSeeMore(section: .popular))
    }

    @objc private func didTapTrendingSeeMore() {
        viewModel.send(.didTapSeeMore(section: .trending))
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              let game = item.selectedGame else { return }
        GameDetailSeedStore.shared.store(games: [game], screen: "Home.tap")
        viewModel.send(.didTapGame(game))
        onGameSelected?(game.id)
    }
}
