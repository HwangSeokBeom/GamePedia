import UIKit

final class LibrarySectionListViewController: UIViewController {

    private enum Section: Hashable {
        case main
    }

    private let route: LibrarySectionListRoute
    private let fetchRecentlyPlayedLibraryUseCase: FetchRecentlyPlayedLibraryUseCase
    private let fetchPlayingLibraryUseCase: FetchPlayingLibraryUseCase
    private let fetchOwnedLibraryUseCase: FetchOwnedLibraryUseCase
    private let fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase
    private let fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase
    private let fetchLibraryFriendRecommendationsUseCase: FetchLibraryFriendRecommendationsUseCase
    private let fetchPlaytimeRecommendationsUseCase: FetchPlaytimeRecommendationsUseCase
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
    private var currentLayoutStyle: LibrarySectionLayoutStyle
    private var loadTask: Task<Void, Never>?

    var onGameSelected: ((Int) -> Void)?
    var onSteamDetailRequested: ((SteamFallbackGameDetailViewState) -> Void)?

    init(
        route: LibrarySectionListRoute,
        fetchRecentlyPlayedLibraryUseCase: FetchRecentlyPlayedLibraryUseCase = FetchRecentlyPlayedLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        fetchPlayingLibraryUseCase: FetchPlayingLibraryUseCase = FetchPlayingLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        fetchOwnedLibraryUseCase: FetchOwnedLibraryUseCase = FetchOwnedLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase = FetchFavoriteGamesUseCase(
            fetchMyFavoritesUseCase: FetchMyFavoritesUseCase(
                favoriteRepository: DefaultFavoriteRepository()
            ),
            gameRepository: DefaultGameRepository()
        ),
        fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase = FetchMyReviewedGamesUseCase(
            fetchMyReviewsUseCase: FetchMyReviewsUseCase(
                reviewRepository: DefaultReviewRepository()
            ),
            gameRepository: DefaultGameRepository()
        ),
        fetchLibraryFriendRecommendationsUseCase: FetchLibraryFriendRecommendationsUseCase = FetchLibraryFriendRecommendationsUseCase(
            libraryRepository: DefaultLibraryRepository(),
            friendRepository: DefaultFriendRepository()
        ),
        fetchPlaytimeRecommendationsUseCase: FetchPlaytimeRecommendationsUseCase = FetchPlaytimeRecommendationsUseCase(
            libraryRepository: DefaultLibraryRepository()
        )
    ) {
        self.route = route
        self.fetchRecentlyPlayedLibraryUseCase = fetchRecentlyPlayedLibraryUseCase
        self.fetchPlayingLibraryUseCase = fetchPlayingLibraryUseCase
        self.fetchOwnedLibraryUseCase = fetchOwnedLibraryUseCase
        self.fetchFavoriteGamesUseCase = fetchFavoriteGamesUseCase
        self.fetchMyReviewedGamesUseCase = fetchMyReviewedGamesUseCase
        self.fetchLibraryFriendRecommendationsUseCase = fetchLibraryFriendRecommendationsUseCase
        self.fetchPlaytimeRecommendationsUseCase = fetchPlaytimeRecommendationsUseCase

        let initialState = Self.initialState(for: route)
        self.currentItems = initialState.items
        self.currentLayoutStyle = initialState.layoutStyle

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
        GameDetailSeedStore.shared.store(items: currentItems, screen: "Library.sectionList.initial")
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
                cell.onActionButtonTapped = nil
                return cell

            case .row(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryGameRowCell.reuseId,
                    for: indexPath
                ) as! LibraryGameRowCell
                cell.configure(with: viewState)
                cell.onTrailingActionTapped = nil
                return cell

            case .message(let viewState):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: LibraryInfoCell.reuseId,
                    for: indexPath
                ) as! LibraryInfoCell
                cell.configure(with: viewState)
                cell.onButtonTapped = nil
                return cell
            }
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, LibraryCollectionItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(deduplicatedItems(currentItems), toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func render(
        items: [LibraryCollectionItem],
        layoutStyle: LibrarySectionLayoutStyle,
        animated: Bool = false
    ) {
        currentItems = items
        GameDetailSeedStore.shared.store(items: currentItems, screen: "Library.sectionList.render")
        if currentLayoutStyle != layoutStyle {
            currentLayoutStyle = layoutStyle
            collectionView.setCollectionViewLayout(makeLayout(), animated: animated)
        }
        applySnapshot()
    }

    private func deduplicatedItems(_ items: [LibraryCollectionItem]) -> [LibraryCollectionItem] {
        var seenItems = Set<LibraryCollectionItem>()
        let deduplicatedItems = items.filter { item in
            let inserted = seenItems.insert(item).inserted
            if !inserted {
                print("[LibrarySectionListSnapshot] droppedDuplicateItem route=\(route.kind) item=\(item)")
            }
            return inserted
        }
        print(
            "[LibrarySectionListSnapshot] " +
            "section=\(route.kind) " +
            "itemCountBeforeDedupe=\(items.count) " +
            "itemCountAfterDedupe=\(deduplicatedItems.count) " +
            "duplicatesRemoved=\(items.count - deduplicatedItems.count > 0)"
        )
        return deduplicatedItems
    }

    private func loadFullContentIfNeeded() {
        switch route.loadBehavior {
        case .staticPreview:
            break

        case .recentlyPlayed:
            loadContent(
                logLabel: "recentlyPlayed",
                layoutStyle: .recentCards,
                emptyMessage: emptyMessageViewState(for: .recentlyPlayed)
            ) { [weak self] in
                guard let self else { return [] }
                let summaries = try await self.fetchRecentlyPlayedLibraryUseCase.execute()
                return summaries.map(self.makeRecentlyPlayedCardItem)
            }

        case .playing:
            loadContent(
                logLabel: "playing",
                layoutStyle: .list,
                emptyMessage: emptyMessageViewState(for: .playing)
            ) { [weak self] in
                guard let self else { return [] }
                let summaries = try await self.fetchPlayingLibraryUseCase.execute()
                return summaries.map(self.makeLibraryRowItem)
            }

        case .ownedGames:
            loadContent(
                logLabel: "owned",
                layoutStyle: .list,
                emptyMessage: emptyMessageViewState(for: .owned)
            ) { [weak self] in
                guard let self else { return [] }
                let collection = try await self.fetchOwnedLibraryUseCase.execute()
                return collection.owned.map(self.makeLibraryRowItem)
            }

        case .wishlist(let sort):
            loadContent(
                logLabel: "wishlist",
                layoutStyle: .list,
                emptyMessage: emptyMessageViewState(for: .wishlist)
            ) { [weak self] in
                guard let self else { return [] }
                let entries = try await self.fetchFavoriteGamesUseCase.execute(
                    sort: sort,
                    screen: "Library.SectionList.Wishlist"
                )
                return entries.map(self.makeWishlistRowItem)
            }

        case .reviewed(let sort):
            loadContent(
                logLabel: "reviewed",
                layoutStyle: .list,
                emptyMessage: emptyMessageViewState(for: .reviewed)
            ) { [weak self] in
                guard let self else { return [] }
                let reviewedGames = try await self.fetchMyReviewedGamesUseCase.execute(
                    sort: sort,
                    screen: "Library.SectionList.Reviewed"
                )
                return reviewedGames.map(self.makeReviewedRowItem)
            }

        case .friendRecommendations:
            loadFriendRecommendationsContent()

        case .playtimeRecommendations:
            loadContent(
                logLabel: "playtimeRecommendations",
                layoutStyle: .list,
                emptyMessage: emptyMessageViewState(for: .playtimeRecommendations)
            ) { [weak self] in
                guard let self else { return [] }
                let recommendations = try await self.fetchPlaytimeRecommendationsUseCase.execute()
                return recommendations.map(self.makePlaytimeRecommendationRowItem)
            }
        }
    }

    private func loadContent(
        logLabel: String,
        layoutStyle: LibrarySectionLayoutStyle,
        emptyMessage: LibraryMessageViewState,
        loader: @escaping () async throws -> [LibraryCollectionItem]
    ) {
        loadTask?.cancel()
        render(items: [.message(Self.loadingMessageViewState(for: route.kind))], layoutStyle: .message)

        loadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let items = try await loader()
                if Task.isCancelled { return }

                await MainActor.run {
                    print("[LibrarySectionList] loadSucceeded kind=\(self.route.kind.title) itemCount=\(items.count)")
                    if items.isEmpty {
                        self.render(items: [.message(emptyMessage)], layoutStyle: .message)
                    } else {
                        if self.route.kind == .owned {
                            print("[LibraryOwnedFullList] responseCount=\(items.count) renderedCount=\(items.count)")
                        }
                        self.render(items: items, layoutStyle: layoutStyle)
                    }
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    print(
                        "[LibrarySectionList] loadFailed " +
                        "kind=\(self.route.kind.title) " +
                        "label=\(logLabel) " +
                        "error=\(error.localizedDescription)"
                    )
                    self.render(
                        items: [.message(Self.errorMessageViewState(for: self.route.kind))],
                        layoutStyle: .message
                    )
                }
            }
        }
    }

    private func loadFriendRecommendationsContent() {
        loadTask?.cancel()
        render(items: [.message(Self.loadingMessageViewState(for: route.kind))], layoutStyle: .message)

        loadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await self.fetchLibraryFriendRecommendationsUseCase.execute()
                if Task.isCancelled { return }

                await MainActor.run {
                    print(
                        "[LibrarySectionList] loadSucceeded kind=\(self.route.kind.title) " +
                        "itemCount=\(result.recommendations.count) source=\(result.source.rawValue) " +
                        "emptyState=\(result.emptyState?.rawValue ?? "nil")"
                    )
                    if result.recommendations.isEmpty {
                        self.render(
                            items: [.message(self.friendRecommendationsEmptyMessageViewState(for: result.emptyState))],
                            layoutStyle: .message
                        )
                    } else {
                        self.render(
                            items: result.recommendations.map(self.makeFriendRecommendationRowItem),
                            layoutStyle: .list
                        )
                    }
                }
            } catch {
                if Task.isCancelled { return }

                await MainActor.run {
                    print(
                        "[LibrarySectionList] loadFailed " +
                        "kind=\(self.route.kind.title) " +
                        "label=friendRecommendations " +
                        "error=\(error.localizedDescription)"
                    )
                    self.render(
                        items: [.message(Self.errorMessageViewState(for: self.route.kind))],
                        layoutStyle: .message
                    )
                }
            }
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            guard let self else { return nil }

            switch self.currentLayoutStyle {
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
            title: L10n.tr("Localizable", "common.alert.infoTitle"),
            message: L10n.tr("Localizable", "common.alert.detailUnavailableMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("Localizable", "common.button.ok"), style: .default))
        present(alert, animated: true)
    }

    private func makeRecentlyPlayedCardItem(from summary: LibraryGameSummary) -> LibraryCollectionItem {
        return .recentCard(
            LibraryRecentGameCardViewState(
                identifier: summary.identifier,
                detailDestination: detailDestination(for: summary),
                title: summary.displayTitle,
                metadataText: recentlyPlayedMetadataText(for: summary),
                ratingText: summary.formattedRatingText,
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                badgeText: "Steam",
                actionTitle: nil,
                isActionEnabled: true
            )
        )
    }

    private func makeLibraryRowItem(from summary: LibraryGameSummary) -> LibraryCollectionItem {
        let subtitleText = librarySubtitleText(for: summary)
        return .row(
            LibraryGameRowViewState(
                identifier: summary.identifier,
                detailDestination: detailDestination(for: summary),
                title: summary.displayTitle,
                subtitleText: subtitleText,
                metadataText: libraryRowMetadataText(for: summary, subtitleText: subtitleText),
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                ratingText: summary.formattedRatingText,
                trailingAction: nil
            )
        )
    }

    private func makeWishlistRowItem(from entry: FavoriteGameEntry) -> LibraryCollectionItem {
        .row(
            LibraryGameRowViewState(
                identifier: LibraryGameIdentifier(
                    source: .igdb,
                    sourceID: String(entry.game.id),
                    canonicalGameID: entry.game.id
                ),
                detailDestination: .igdb(entry.game.id),
                title: entry.game.displayTitle,
                subtitleText: "\(entry.game.genre) · \(releaseText(for: entry.game.releaseYear))",
                metadataText: entry.game.platform,
                coverImageURL: entry.game.coverImageURL,
                ratingText: entry.game.rating.isFinite && entry.game.rating >= 0
                    ? LocalizedNumberFormatter.oneFraction(entry.game.rating)
                    : nil,
                trailingAction: nil
            )
        )
    }

    private func makeReviewedRowItem(from reviewedGame: ReviewedGame) -> LibraryCollectionItem {
        .row(
            LibraryGameRowViewState(
                identifier: LibraryGameIdentifier(
                    source: .igdb,
                    sourceID: reviewedGame.reviewId,
                    canonicalGameID: reviewedGame.gameId
                ),
                detailDestination: .igdb(reviewedGame.gameId),
                title: reviewedGame.game.displayTitle,
                subtitleText: reviewedGame.contentPreview,
                metadataText: "\(reviewedGame.game.genre) · \(releaseText(for: reviewedGame.game.releaseYear))",
                coverImageURL: reviewedGame.game.coverImageURL,
                fallbackCoverImageURLs: [],
                ratingText: reviewedGame.rating.isFinite
                    ? LocalizedNumberFormatter.oneFraction(reviewedGame.rating)
                    : nil,
                trailingAction: nil
            )
        )
    }

    private func makeFriendRecommendationRowItem(
        from recommendation: SteamFriendRecommendation
    ) -> LibraryCollectionItem {
        let summary = recommendation.game
        return .row(
            LibraryGameRowViewState(
                identifier: summary.identifier,
                detailDestination: detailDestination(for: summary),
                title: summary.displayTitle,
                subtitleText: friendRecommendationSubtitleText(for: recommendation),
                metadataText: librarySubtitleText(for: summary),
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                ratingText: summary.formattedRatingText,
                trailingAction: nil
            )
        )
    }

    private func makePlaytimeRecommendationRowItem(
        from recommendation: PlaytimeRecommendation
    ) -> LibraryCollectionItem {
        let summary = recommendation.game
        return .row(
            LibraryGameRowViewState(
                identifier: summary.identifier,
                detailDestination: detailDestination(for: summary),
                title: summary.displayTitle,
                subtitleText: playtimeRecommendationSubtitleText(for: recommendation),
                metadataText: librarySubtitleText(for: summary),
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                ratingText: summary.formattedRatingText,
                trailingAction: nil
            )
        )
    }

    private func recentlyPlayedMetadataText(for summary: LibraryGameSummary) -> String {
        let display = RecentPlayMetadataFormatter.makeDisplay(
            lastPlayedAt: summary.lastPlayedAt,
            hasReliableLastPlayedAt: summary.hasReliableLastPlayedAt,
            recentPlaytimeMinutes: summary.recentPlaytimeMinutes,
            fallbackReason: summary.recentPlayFallbackReason
        )
        return display.finalText
    }

    private func librarySubtitleText(for summary: LibraryGameSummary) -> String {
        conciseLibraryMetadataText(for: summary) ?? steamLibraryFallbackText(for: summary)
    }

    private func libraryRowMetadataText(
        for summary: LibraryGameSummary,
        subtitleText: String
    ) -> String {
        if summary.gameSource == .steam,
           let playtimeText = SteamPlaytimeFormatter.compactPlaytimeText(minutes: summary.playtimeMinutes) {
            return playtimeText
        }

        guard let platformText = normalizedPlatformText(for: summary),
              subtitleText.contains(platformText) == false else {
            return ""
        }

        return platformText
    }

    private func conciseLibraryMetadataText(for summary: LibraryGameSummary) -> String? {
        if summary.gameSource == .steam {
            if let genreText = summary.displayableGenreText {
                return "Steam · \(genreText)"
            }

            return "Steam"
        }

        let components = [
            summary.displayableGenreText,
            knownReleaseText(for: summary)
        ].compactMap { $0 }

        guard !components.isEmpty else { return nil }
        return components.joined(separator: " · ")
    }

    private func knownReleaseText(for summary: LibraryGameSummary) -> String? {
        guard summary.releaseYear > 0 else { return nil }
        return "\(summary.releaseYear)"
    }

    private func normalizedPlatformText(for summary: LibraryGameSummary) -> String? {
        guard let platformText = sanitized(summary.platform),
              platformText != "—" else {
            return nil
        }

        return platformText
    }

    private func steamLibraryFallbackText(for summary: LibraryGameSummary) -> String {
        guard summary.identifier.source == .steam else {
            return L10n.tr("Localizable", "library.sectionList.fallback.enriching")
        }

        return summary.shouldOpenFullGamePediaDetail
            ? "Steam"
            : "Steam · \(L10n.tr("Localizable", "library.sectionList.fallback.enriching"))"
    }

    private func detailDestination(for summary: LibraryGameSummary) -> LibraryGameDetailDestination? {
        if summary.shouldOpenFullGamePediaDetail,
           let igdbGameID = summary.igdbGameId,
           igdbGameID > 0 {
            print(
                "[DetailRouteMapping] " +
                "screen=Library.sectionList.\(route.kind.title) " +
                "title=\(summary.displayTitle) " +
                "externalGameId=\(summary.externalGameId) " +
                "igdbGameId=\(summary.igdbGameId.map(String.init) ?? "nil") " +
                "detailAvailable=\(summary.detailAvailable) " +
                "createdDestination=igdb:\(igdbGameID) " +
                "blockedReason=nil"
            )
            return .igdb(igdbGameID)
        }

        guard summary.shouldOpenSteamFallbackDetail else {
            print(
                "[DetailRouteMapping] " +
                "screen=Library.sectionList.\(route.kind.title) " +
                "title=\(summary.displayTitle) " +
                "externalGameId=\(summary.externalGameId) " +
                "igdbGameId=\(summary.igdbGameId.map(String.init) ?? "nil") " +
                "detailAvailable=\(summary.detailAvailable) " +
                "createdDestination=nil " +
                "blockedReason=\(summary.detailAvailable ? "missingPositiveIgdbGameId" : "detailUnavailable")"
            )
            return nil
        }

        print(
            "[DetailRouteMapping] " +
            "screen=Library.sectionList.\(route.kind.title) " +
            "title=\(summary.displayTitle) " +
            "externalGameId=\(summary.externalGameId) " +
            "igdbGameId=\(summary.igdbGameId.map(String.init) ?? "nil") " +
            "detailAvailable=\(summary.detailAvailable) " +
            "createdDestination=steamFallback " +
            "blockedReason=nil"
        )
        return .steamFallback(
            SteamFallbackGameDetailViewState(
                title: summary.displayTitle,
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                sourceLabelText: "Steam",
                metadataText: steamMetadataText(for: summary),
                descriptionText: L10n.tr("Localizable", "library.sectionList.fallback.importedFromSteam"),
                playtimeValueText: SteamPlaytimeFormatter.expandedPlaytimeValue(
                    minutes: summary.playtimeMinutes ?? summary.recentPlaytimeMinutes
                ),
                externalGameId: summary.externalGameId,
                gameSource: summary.gameSource,
                metadataEnriched: summary.metadataEnriched,
                matchStatus: summary.matchStatus,
                enrichmentStatus: summary.enrichmentStatus
            )
        )
    }

    private func steamMetadataText(for summary: LibraryGameSummary) -> String {
        if let genre = summary.displayableGenreText {
            return "Steam · \(genre)"
        }

        return summary.shouldOpenFullGamePediaDetail
            ? "Steam"
            : "Steam · \(L10n.tr("Localizable", "library.sectionList.fallback.enriching"))"
    }

    private func playtimeRecommendationSubtitleText(
        for recommendation: PlaytimeRecommendation
    ) -> String {
        guard let reason = sanitized(recommendation.reason) else {
            return L10n.tr("Localizable", "library.sectionList.playtimeRecommendation.default")
        }

        switch reason {
        case "자주 즐기는 장르와 잘 맞아요":
            return L10n.tr("Localizable", "library.sectionList.playtimeRecommendation.genreMatch")
        default:
            return reason
        }
    }

    private func friendRecommendationSubtitleText(
        for recommendation: SteamFriendRecommendation
    ) -> String {
        let friendCount = max(recommendation.friendCount, 0)
        if let reason = sanitized(recommendation.reason), reason.contains("플레이 중") {
            return friendCount > 0
                ? L10n.tr("Localizable", "library.sectionList.friendRecommendation.playingCount", friendCount)
                : L10n.tr("Localizable", "library.sectionList.friendRecommendation.playingFallback")
        }

        if let reason = sanitized(recommendation.reason), reason.contains("보유") {
            return L10n.tr("Localizable", "library.sectionList.friendRecommendation.ownedFallback")
        }

        return friendCount > 0
            ? L10n.tr("Localizable", "library.sectionList.friendRecommendation.noticedCount", friendCount)
            : L10n.tr("Localizable", "library.sectionList.friendRecommendation.noticedFallback")
    }

    private func friendRecommendationsEmptyMessageViewState(
        for emptyState: LibraryFriendRecommendationsEmptyState?
    ) -> LibraryMessageViewState {
        let title: String?
        let message: String
        let detailText: String?

        switch emptyState ?? .noFriendData {
        case .noFriendData:
            title = L10n.tr("Localizable", "library.sectionList.friendEmpty.noDataTitle")
            message = L10n.tr("Localizable", "library.sectionList.friendEmpty.noDataMessage")
            detailText = L10n.tr("Localizable", "library.sectionList.friendEmpty.noDataDetail")
        case .insufficientActivity:
            title = L10n.tr("Localizable", "library.sectionList.friendEmpty.insufficientTitle")
            message = L10n.tr("Localizable", "library.sectionList.friendEmpty.insufficientMessage")
            detailText = nil
        case .steamUnavailable:
            title = L10n.tr("Localizable", "library.sectionList.friendEmpty.steamUnavailableTitle")
            message = L10n.tr("Localizable", "library.sectionList.friendEmpty.steamUnavailableMessage")
            detailText = nil
        }

        return LibraryMessageViewState(
            id: "sectionList.empty.friendRecommendations.\((emptyState ?? .noFriendData).rawValue)",
            style: .empty,
            title: title,
            message: message,
            detailText: detailText,
            buttonTitle: nil,
            action: nil
        )
    }

    private func releaseText(for year: Int) -> String {
        year > 0 ? "\(year)" : L10n.tr("Localizable", "common.status.upcoming")
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func initialState(
        for route: LibrarySectionListRoute
    ) -> (layoutStyle: LibrarySectionLayoutStyle, items: [LibraryCollectionItem]) {
        switch route.loadBehavior {
        case .staticPreview:
            return (route.layoutStyle, route.items)
        case .recentlyPlayed,
             .playing,
             .ownedGames,
             .wishlist,
             .reviewed,
             .friendRecommendations,
             .playtimeRecommendations:
            return (.message, [.message(loadingMessageViewState(for: route.kind))])
        }
    }

    private static func loadingMessageViewState(for kind: LibrarySectionKind) -> LibraryMessageViewState {
        let message: String
        switch kind {
        case .recentlyPlayed:
            message = L10n.tr("Localizable", "library.sectionList.loading.recentlyPlayed")
        case .playing:
            message = L10n.tr("Localizable", "library.sectionList.loading.playing")
        case .owned:
            message = L10n.tr("Localizable", "library.sectionList.loading.owned")
        case .wishlist:
            message = L10n.tr("Localizable", "library.sectionList.loading.wishlist")
        case .reviewed:
            message = L10n.tr("Localizable", "library.sectionList.loading.reviewed")
        case .friendRecommendations:
            message = L10n.tr("Localizable", "library.sectionList.loading.friendRecommendations")
        case .playtimeRecommendations:
            message = L10n.tr("Localizable", "library.sectionList.loading.playtimeRecommendations")
        }

        return LibraryMessageViewState(
            id: "sectionList.loading.\(kind.rawValue)",
            style: .loading,
            title: nil,
            message: message,
            detailText: nil,
            buttonTitle: nil,
            action: nil
        )
    }

    private func emptyMessageViewState(for kind: LibrarySectionKind) -> LibraryMessageViewState {
        let message: String
        switch kind {
        case .recentlyPlayed:
            message = L10n.tr("Localizable", "library.sectionList.empty.recentlyPlayed")
        case .playing:
            message = L10n.tr("Localizable", "library.sectionList.empty.playing")
        case .owned:
            message = L10n.tr("Localizable", "library.sectionList.empty.owned")
        case .wishlist:
            message = L10n.tr("Localizable", "library.sectionList.empty.wishlist")
        case .reviewed:
            message = L10n.tr("Localizable", "library.sectionList.empty.reviewed")
        case .friendRecommendations:
            message = L10n.tr("Localizable", "library.sectionList.empty.friendRecommendations")
        case .playtimeRecommendations:
            message = L10n.tr("Localizable", "library.sectionList.empty.playtimeRecommendations")
        }

        return LibraryMessageViewState(
            id: "sectionList.empty.\(kind.rawValue)",
            style: .empty,
            title: nil,
            message: message,
            detailText: nil,
            buttonTitle: nil,
            action: nil
        )
    }

    private static func errorMessageViewState(for kind: LibrarySectionKind) -> LibraryMessageViewState {
        let message: String
        switch kind {
        case .recentlyPlayed:
            message = L10n.tr("Localizable", "library.sectionList.error.recentlyPlayed")
        case .playing:
            message = L10n.tr("Localizable", "library.sectionList.error.playing")
        case .owned:
            message = L10n.tr("Localizable", "library.sectionList.error.owned")
        case .wishlist:
            message = L10n.tr("Localizable", "library.sectionList.error.wishlist")
        case .reviewed:
            message = L10n.tr("Localizable", "library.sectionList.error.reviewed")
        case .friendRecommendations:
            message = L10n.tr("Localizable", "library.sectionList.error.friendRecommendations")
        case .playtimeRecommendations:
            message = L10n.tr("Localizable", "library.sectionList.error.playtimeRecommendations")
        }

        return LibraryMessageViewState(
            id: "sectionList.error.\(kind.rawValue)",
            style: .error,
            title: nil,
            message: message,
            detailText: nil,
            buttonTitle: nil,
            action: nil
        )
    }
}

extension LibrarySectionListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .recentCard(let viewState):
            switch viewState.detailDestination {
            case .igdb(let gameID):
                GameDetailSeedStore.shared.store(items: [item], screen: "Library.sectionList.tap")
                print(
                    "[GameTap] screen=Library.sectionList.\(route.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=igdb:\(gameID) " +
                    "igdbGameId=\(gameID) " +
                    "externalGameId=\(viewState.identifier.sourceID)"
                )
                onGameSelected?(gameID)
            case .steamFallback(let steamViewState):
                print(
                    "[GameTap] screen=Library.sectionList.\(route.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=steamFallback " +
                    "igdbGameId=nil " +
                    "externalGameId=\(steamViewState.externalGameId)"
                )
                onSteamDetailRequested?(steamViewState)
            case .none:
                presentUnavailableDetailAlert()
            }

        case .row(let viewState):
            switch viewState.detailDestination {
            case .igdb(let gameID):
                GameDetailSeedStore.shared.store(items: [item], screen: "Library.sectionList.tap")
                print(
                    "[GameTap] screen=Library.sectionList.\(route.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=igdb:\(gameID) " +
                    "igdbGameId=\(gameID) " +
                    "externalGameId=\(viewState.identifier.sourceID)"
                )
                onGameSelected?(gameID)
            case .steamFallback(let steamViewState):
                print(
                    "[GameTap] screen=Library.sectionList.\(route.kind.title) " +
                    "title=\(viewState.title) " +
                    "destination=steamFallback " +
                    "igdbGameId=nil " +
                    "externalGameId=\(steamViewState.externalGameId)"
                )
                onSteamDetailRequested?(steamViewState)
            case .none:
                presentUnavailableDetailAlert()
            }

        case .message:
            break
        }
    }
}
