import UIKit

final class LibraryViewController: BaseViewController<LibraryRootView, LibraryState> {

    private let viewModel: LibraryViewModel
    private var dataSource: UICollectionViewDiffableDataSource<LibrarySectionKind, LibraryCollectionItem>!
    private var currentSections: [LibrarySectionViewState] = []
    private var lastPresentedErrorMessage: String?
    private let refreshControl = UIRefreshControl()

    var onGameSelected: ((Int) -> Void)?
    var onSteamLinkRequested: ((URL) -> Void)?

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
        setupCollectionView()
        setupBindings()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func render(_ state: LibraryState) {
        rootView.render(state)
        applySnapshot(sections: state.sections, focusedSection: state.pendingFocusSection)

        if !state.isRefreshing {
            refreshControl.endRefreshing()
        }

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            let alert = UIAlertController(title: "오류", message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "내 라이브러리"
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    private func setupCollectionView() {
        rootView.setCollectionViewLayout(makeLayout())
        rootView.collectionView.delegate = self
        rootView.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        rootView.collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
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

        dataSource = UICollectionViewDiffableDataSource<LibrarySectionKind, LibraryCollectionItem>(
            collectionView: rootView.collectionView
        ) { [weak self] collectionView, indexPath, item in
            guard let self else { return UICollectionViewCell() }

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
                    guard viewState.buttonTitle != nil else { return }
                    self?.viewModel.send(.didTapSteamLink)
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
                case .reviewed:
                    self.viewModel.send(.didTapSeeAllReviewed)
                case .playing, .wishlist:
                    break
                }
            }
            return headerView
        }
    }

    private func setupBindings() {
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

        viewModel.onRoute = { [weak self] route in
            switch route {
            case .showGameDetail(let gameID):
                self?.onGameSelected?(gameID)
            case .showSteamLink(let url):
                self?.onSteamLinkRequested?(url)
            case .showRecentlyPlayed, .showReviewed:
                break
            }
        }
    }

    private func applySnapshot(sections: [LibrarySectionViewState], focusedSection: LibrarySectionKind?) {
        currentSections = sections

        var snapshot = NSDiffableDataSourceSnapshot<LibrarySectionKind, LibraryCollectionItem>()
        let sectionKinds = sections.map(\.kind)
        snapshot.appendSections(sectionKinds)

        for section in sections {
            snapshot.appendItems(section.items, toSection: section.kind)
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
        guard dataSource.itemIdentifier(for: indexPath) == firstItem else { return }
        rootView.collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
        viewModel.send(.didConsumeInitialFocus)
    }

    private func presentRemoveFavoriteAlert(identifier: LibraryGameIdentifier, title: String) {
        let alert = UIAlertController(
            title: "찜을 해제할까요?",
            message: "\"\(title)\"을 찜한 게임 목록에서 제거합니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.viewModel.send(.didConfirmRemoveFavorite(identifier))
        })
        present(alert, animated: true)
    }

    @objc
    private func didPullToRefresh() {
        viewModel.send(.pullToRefresh)
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
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(176),
            heightDimension: .estimated(286)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 28, trailing: 16)
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
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 28, trailing: 16)
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
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 28, trailing: 16)
        return section
    }

    private func makeHeaderBoundaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(36)
            ),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}

extension LibraryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section < currentSections.count,
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        let section = currentSections[indexPath.section]

        switch item {
        case .recentCard(let viewState):
            viewModel.send(.didTapRecentlyPlayedGame(viewState.identifier))
        case .row(let viewState):
            switch section.kind {
            case .playing:
                viewModel.send(.didTapPlayingGame(viewState.identifier))
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

    private let headerView: SectionHeaderView = {
        let view = SectionHeaderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        headerView.configure(
            title: sectionKind.title,
            systemImageName: sectionKind.systemImageName,
            tintColor: .gpPrimaryLight,
            showSeeMore: showsSeeMore
        )
    }

    private func setup() {
        addSubview(headerView)
        headerView.seeMoreButton.addTarget(self, action: #selector(didTapSeeMore), for: .touchUpInside)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            headerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc
    private func didTapSeeMore() {
        onSeeMoreTapped?()
    }
}
