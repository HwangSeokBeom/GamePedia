import UIKit

final class LibrarySectionListViewController: UIViewController {

    private enum Section: Hashable {
        case main
    }

    private let route: LibrarySectionListRoute
    private let fetchOwnedLibraryUseCase: FetchOwnedLibraryUseCase
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: makeLayout()
        )
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Section, LibraryCollectionItem>!
    private var currentItems: [LibraryCollectionItem]
    private var loadTask: Task<Void, Never>?

    var onGameSelected: ((Int) -> Void)?
    var onSteamDetailRequested: ((SteamFallbackGameDetailViewState) -> Void)?

    init(
        route: LibrarySectionListRoute,
        fetchOwnedLibraryUseCase: FetchOwnedLibraryUseCase = FetchOwnedLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        )
    ) {
        self.route = route
        self.fetchOwnedLibraryUseCase = fetchOwnedLibraryUseCase
        self.currentItems = route.items
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpBackground
        navigationItem.title = route.title
        navigationItem.largeTitleDisplayMode = .never
        setupCollectionView()
        setupDataSource()
        applySnapshot()
        loadFullContentIfNeeded()
    }

    deinit {
        loadTask?.cancel()
    }

    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 32, right: 0)

        collectionView.register(
            LibraryGameCardCell.self,
            forCellWithReuseIdentifier: LibraryGameCardCell.reuseId
        )
        collectionView.register(
            LibraryGameRowCell.self,
            forCellWithReuseIdentifier: LibraryGameRowCell.reuseId
        )
        collectionView.register(
            LibraryInfoCell.self,
            forCellWithReuseIdentifier: LibraryInfoCell.reuseId
        )

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, LibraryCollectionItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            switch item {
            case .recentCard(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryGameCardCell.reuseId,
                    for: indexPath
                ) as! LibraryGameCardCell
                cell.configure(with: viewState)
                return cell

            case .row(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryGameRowCell.reuseId,
                    for: indexPath
                ) as! LibraryGameRowCell
                cell.configure(with: viewState)
                return cell

            case .message(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryInfoCell.reuseId,
                    for: indexPath
                ) as! LibraryInfoCell
                cell.configure(with: viewState)
                return cell
            }
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, LibraryCollectionItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(currentItems, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func loadFullContentIfNeeded() {
        switch route.loadBehavior {
        case .staticPreview:
            break
        case .ownedGames:
            loadFullOwnedGames()
        }
    }

    private func loadFullOwnedGames() {
        guard route.kind == .owned else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let collection = try await fetchOwnedLibraryUseCase.execute()
                if Task.isCancelled { return }

                let items = collection.owned.map(makeOwnedRowItem)
                await MainActor.run {
                    guard !items.isEmpty else { return }
                    self.currentItems = items
                    self.applySnapshot()
                }
            } catch {
                print("[LibraryOwnedList] loadFailed error=\(error.localizedDescription)")
            }
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            guard let self else { return nil }

            switch route.layoutStyle {
            case .recentCards:
                return self.makeRecentCardsSection(environment: environment)
            case .list, .message:
                return self.makeListSection()
            }
        }
    }

    private func makeRecentCardsSection(
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let columnCount = environment.container.effectiveContentSize.width >= 700 ? 3 : 2
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(280)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(280)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: columnCount
        )
        group.interItemSpacing = .fixed(12)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16)
        return section
    }

    private func makeListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(88)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(88)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16)
        return section
    }

    private func presentUnavailableDetailAlert() {
        let alert = UIAlertController(
            title: "안내",
            message: "게임 상세 정보를 아직 불러올 수 없어요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func makeOwnedRowItem(from summary: LibraryGameSummary) -> LibraryCollectionItem {
        let subtitleText = ownedSubtitleText(for: summary)
        return .row(
            LibraryGameRowViewState(
                identifier: summary.identifier,
                detailDestination: detailDestination(for: summary),
                title: summary.displayTitle,
                subtitleText: subtitleText,
                metadataText: ownedMetadataText(for: summary, subtitleText: subtitleText),
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                ratingText: summary.rating.map { String(format: "%.1f", $0) },
                trailingAction: nil
            )
        )
    }

    private func ownedSubtitleText(for summary: LibraryGameSummary) -> String {
        if summary.gameSource == .steam,
           let genre = summary.displayableGenreText {
            return "Steam · \(genre)"
        }

        if let genre = summary.displayableGenreText {
            if summary.releaseYear > 0 {
                return "\(genre) · \(summary.releaseYear)"
            }
            return genre
        }

        return summary.gameSource == .steam ? "Steam" : "정보 보강 중"
    }

    private func ownedMetadataText(
        for summary: LibraryGameSummary,
        subtitleText: String
    ) -> String {
        if summary.gameSource == .steam,
           let playtimeText = SteamPlaytimeFormatter.compactPlaytimeText(minutes: summary.playtimeMinutes) {
            return playtimeText
        }

        guard let platform = sanitized(summary.platform),
              platform != "—",
              subtitleText.contains(platform) == false else {
            return ""
        }

        return platform
    }

    private func detailDestination(for summary: LibraryGameSummary) -> LibraryGameDetailDestination? {
        if summary.matchStatus == .confirmed,
           let igdbGameID = summary.igdbGameId {
            return .igdb(igdbGameID)
        }

        guard summary.gameSource == .steam,
              summary.detailAvailable else {
            return nil
        }

        return .steamFallback(
            SteamFallbackGameDetailViewState(
                title: summary.displayTitle,
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                sourceLabelText: "Steam",
                metadataText: steamMetadataText(for: summary),
                descriptionText: "Steam에서 가져온 게임입니다.",
                playtimeValueText: SteamPlaytimeFormatter.expandedPlaytimeValue(
                    minutes: summary.playtimeMinutes ?? summary.recentPlaytimeMinutes
                ),
                externalGameId: summary.externalGameId,
                gameSource: summary.gameSource,
                metadataEnriched: summary.metadataEnriched,
                matchStatus: summary.matchStatus
            )
        )
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func steamMetadataText(for summary: LibraryGameSummary) -> String {
        if let genre = summary.displayableGenreText {
            return "Steam · \(genre)"
        }

        return summary.matchStatus == .confirmed ? "Steam" : "Steam · 정보 보강 중"
    }
}

extension LibrarySectionListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .recentCard(let viewState):
            switch viewState.detailDestination {
            case .igdb(let gameID):
                onGameSelected?(gameID)
            case .steamFallback(let steamViewState):
                onSteamDetailRequested?(steamViewState)
            case .none:
                presentUnavailableDetailAlert()
            }

        case .row(let viewState):
            switch viewState.detailDestination {
            case .igdb(let gameID):
                onGameSelected?(gameID)
            case .steamFallback(let steamViewState):
                onSteamDetailRequested?(steamViewState)
            case .none:
                presentUnavailableDetailAlert()
            }

        case .message:
            break
        }
    }
}
