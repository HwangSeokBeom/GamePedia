import UIKit

final class HomeGameListViewController: BaseViewController<HomeGameListRootView, HomeGameListState> {

    private let viewModel: HomeGameListViewModel
    private var dataSource: UICollectionViewDiffableDataSource<Int, Game>!

    var onGameSelected: ((Int) -> Void)?

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
        rootView.render(state)
        applySnapshot(state.games)
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
            return cell
        }
    }

    private func applySnapshot(_ games: [Game]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Game>()
        snapshot.appendSections([0])
        snapshot.appendItems(games, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension HomeGameListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let game = dataSource.itemIdentifier(for: indexPath) else { return }
        onGameSelected?(game.id)
    }
}
