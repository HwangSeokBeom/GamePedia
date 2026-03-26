import UIKit

final class LibraryViewController: BaseViewController<LibraryRootView, LibraryState> {

    private enum Section {
        case main
    }

    private let viewModel: LibraryViewModel
    private var dataSource: UICollectionViewDiffableDataSource<Section, LibraryGameCardItem>!
    private var lastPresentedErrorMessage: String?

    var onGameSelected: ((Int) -> Void)?

    override init(rootView: LibraryRootView = LibraryRootView()) {
        self.viewModel = LibraryViewModel()
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.setUsesNavigationTitle(true)
        setupCollectionView()
        setupBindings()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "내 라이브러리"
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    private func setupCollectionView() {
        rootView.collectionView.delegate = self

        dataSource = UICollectionViewDiffableDataSource<Section, LibraryGameCardItem>(
            collectionView: rootView.collectionView
        ) { [weak self] collectionView, indexPath, item in
            guard let self else { return UICollectionViewCell() }
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: LibraryGameCardCell.reuseId,
                for: indexPath
            ) as! LibraryGameCardCell
            cell.configure(with: item)
            cell.onFavoriteButtonTapped = { [weak self] in
                self?.presentRemoveFavoriteAlert(gameId: item.id, title: item.title)
            }
            return cell
        }
    }

    private func setupBindings() {
        rootView.onTabSelected = { [weak self] index in
            self?.viewModel.send(.didSelectTab(index))
        }
        rootView.onFilterSelected = { [weak self] index in
            self?.viewModel.send(.didSelectSort(index))
        }
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
    }

    override func render(_ state: LibraryState) {
        rootView.render(state)
        applySnapshot(items: state.items)

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            let alert = UIAlertController(title: "오류", message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        }
    }

    private func applySnapshot(items: [LibraryGameCardItem]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, LibraryGameCardItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.rootView.updateCollectionHeight()
            self?.rootView.render(self?.viewModel.state ?? LibraryState())
        }
    }

    private func presentRemoveFavoriteAlert(gameId: Int, title: String) {
        let alert = UIAlertController(
            title: "찜을 해제할까요?",
            message: "\"\(title)\"을 찜한 게임 목록에서 제거합니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.viewModel.send(.didConfirmRemoveFavorite(gameId: gameId))
        })
        present(alert, animated: true)
    }
}

extension LibraryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 12) / 2)
        return CGSize(width: width, height: width * 1.54)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onGameSelected?(item.id)
    }
}
