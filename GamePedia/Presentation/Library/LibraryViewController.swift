import UIKit

final class LibraryViewController: BaseViewController<LibraryRootView, LibraryState> {

    private let viewModel: LibraryViewModel
    private var dataSource: UICollectionViewDiffableDataSource<LibrarySectionKind, LibraryCollectionItem>!
    private var currentSections: [LibrarySectionViewState] = []
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?
    private var lastPresentedSteamOnboarding: LibraryOnboardingViewState?
    private let refreshControl = UIRefreshControl()
    private var toastHideWorkItem: DispatchWorkItem?
    private weak var toastView: LibraryToastView?
    private lazy var syncOwnedLibraryBarButtonItem = UIBarButtonItem(
        title: "Steam 보관함 가져오기",
        style: .plain,
        target: self,
        action: #selector(didTapSyncOwnedSteamLibrary)
    )
    private lazy var steamManagementBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "ellipsis.circle"),
        style: .plain,
        target: nil,
        action: nil
    )

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
        print("[Library] viewWillAppear")
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
    }

    func retrySteamPrivacyGuidance() {
        viewModel.send(.retrySteamPrivacyGuideTapped)
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
                    break
                case .friendRecommendations:
                    break
                case .reviewed:
                    self.viewModel.send(.didTapSeeAllReviewed)
                case .wishlist:
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
        print("[Library] pullToRefresh")
        viewModel.send(.pullToRefresh)
    }

    @objc
    private func didTapSyncOwnedSteamLibrary() {
        viewModel.send(.syncOwnedSteamLibraryButtonTapped)
    }

    private func updateNavigationItems(with state: LibraryState) {
        guard state.isSteamConnected else {
            navigationItem.rightBarButtonItems = nil
            return
        }

        syncOwnedLibraryBarButtonItem.title = state.isSyncingOwnedSteamLibrary ? "가져오는 중..." : "Steam 보관함 가져오기"
        syncOwnedLibraryBarButtonItem.isEnabled = !state.isSyncingOwnedSteamLibrary && !state.isUnlinkingSteamAccount
        steamManagementBarButtonItem.isEnabled = !state.isSyncingOwnedSteamLibrary && !state.isUnlinkingSteamAccount
        steamManagementBarButtonItem.menu = makeSteamManagementMenu()
        navigationItem.rightBarButtonItems = [steamManagementBarButtonItem, syncOwnedLibraryBarButtonItem]
    }

    private func makeSteamManagementMenu() -> UIMenu {
        let unlinkAction = UIAction(
            title: "Steam 연동 해제",
            image: UIImage(systemName: "link.badge.minus"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.presentSteamUnlinkConfirmationAlert()
        }

        return UIMenu(title: "", children: [unlinkAction])
    }

    private func presentSteamUnlinkConfirmationAlert() {
        let alert = UIAlertController(
            title: "Steam 연동을 해제할까요?",
            message: "연동을 해제하면 Steam에서 가져온 최근 플레이 및 보유 게임 연결 정보가 더 이상 동기화되지 않아요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "연동 해제", style: .destructive) { [weak self] _ in
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
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
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
