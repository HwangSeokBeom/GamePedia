import UIKit

final class HomeGameListViewController: BaseViewController<HomeGameListRootView, HomeGameListState> {

    private let viewModel: HomeGameListViewModel
    private var dataSource: UICollectionViewDiffableDataSource<Int, Game>!
    private var lastRenderedWishlistedGameIDs = Set<Int>()

    var section: HomeSection { viewModel.state.section }
    var onGameSelected: ((Int) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    init(
        rootView: HomeGameListRootView,
        viewModel: HomeGameListViewModel
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        configureNavigationItem()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataSource()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func render(_ state: HomeGameListState) {
        GameDetailSeedStore.shared.store(games: state.games, screen: "Home.list.render")
        rootView.render(state)
        applySnapshot(state: state)
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.title = viewModel.state.section.listTitle
        }
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
    }

    private func setupDataSource() {
        rootView.collectionView.delegate = self
        dataSource = UICollectionViewDiffableDataSource<Int, Game>(
            collectionView: rootView.collectionView
        ) { [weak self] collectionView, indexPath, game in
            guard let self else { return UICollectionViewCell() }
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: GameRowCell.reuseId,
                for: indexPath
            ) as! GameRowCell
            cell.configure(
                with: game,
                resolvedTitle: game.displayTitle,
                isWishlisted: self.viewModel.state.wishlistedGameIDs.contains(game.id)
            )
            cell.onFavoriteButtonTapped = { [weak self] in
                self?.performAuthenticatedAction(for: .favoriteGame) { [weak self] in
                    self?.viewModel.send(.didTapFavorite(gameId: game.id))
                }
            }
            return cell
        }
    }

    private func applySnapshot(state: HomeGameListState) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Game>()
        snapshot.appendSections([0])
        snapshot.appendItems(state.games, toSection: 0)
        reconfigureWishlistItemsIfNeeded(state: state, snapshot: &snapshot)
        dataSource.apply(snapshot, animatingDifferences: false)
        lastRenderedWishlistedGameIDs = state.wishlistedGameIDs
    }

    private func reconfigureWishlistItemsIfNeeded(
        state: HomeGameListState,
        snapshot: inout NSDiffableDataSourceSnapshot<Int, Game>
    ) {
        guard dataSource.snapshot().numberOfItems > 0,
              lastRenderedWishlistedGameIDs != state.wishlistedGameIDs else {
            return
        }

        let changedGameIDs = lastRenderedWishlistedGameIDs.symmetricDifference(state.wishlistedGameIDs)
        let itemsToRefresh = state.games.filter { changedGameIDs.contains($0.id) }

        guard itemsToRefresh.isEmpty == false else { return }

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(itemsToRefresh)
        } else {
            snapshot.reloadItems(itemsToRefresh)
        }
    }

    private func performAuthenticatedAction(
        for context: RestrictedActionContext,
        action: @escaping () -> Void
    ) {
        guard let onAuthenticationRequired else {
            action()
            return
        }

        onAuthenticationRequired(context, action)
    }
}

extension HomeGameListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let game = dataSource.itemIdentifier(for: indexPath) else { return }
        GameDetailSeedStore.shared.store(games: [game], screen: "Home.list.tap")
        onGameSelected?(game.id)
    }
}
