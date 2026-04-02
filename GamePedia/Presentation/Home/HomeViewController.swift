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
    }

    private func cellProvider(
        collectionView: UICollectionView,
        indexPath: IndexPath,
        item: HomeCollectionItem
    ) -> UICollectionViewCell {
        switch item {
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

        guard let section = HomeRootView.Section(rawValue: indexPath.section) else {
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

    private func handle(_ route: HomeRoute) {
        switch route {
        case .presentHomeFilterSheet(let filter):
            presentHomeFilterSheet(filter: filter)
        case .showGameList, .showNotifications:
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
        snapshot.appendSections(HomeRootView.Section.allCases)
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
        for section in HomeRootView.Section.allCases {
            let indexPath = IndexPath(item: 0, section: section.rawValue)
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
        viewModel.send(.didTapGame(game))
        onGameSelected?(game.id)
    }
}
