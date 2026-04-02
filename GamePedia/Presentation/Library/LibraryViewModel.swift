import Combine
import Foundation

final class LibraryViewModel {
    private enum SectionLoadEvent {
        case overview(Result<LibraryOverview, Error>)
        case playtimeRecommendations(Result<[PlaytimeRecommendation], Error>)
        case friendRecommendations(Result<LibraryFriendRecommendationsResult, Error>)
        case wishlist(Result<[FavoriteGameEntry], Error>)
        case reviewed(Result<[ReviewedGame], Error>)
    }

    private enum LoadTrigger {
        case initial
        case refresh

        var logName: String {
            switch self {
            case .initial:
                return "initial"
            case .refresh:
                return "refresh"
            }
        }
    }

    private enum PreviewLimit {
        static let recentCards = 4
        static let listRows = 3
        static let recommendationRows = 4
    }

    private enum SteamOwnedSyncTrigger {
        case manual
        case retry
        case silentAutomatic

        var logName: String {
            switch self {
            case .manual:
                return "manual"
            case .retry:
                return "retry"
            case .silentAutomatic:
                return "silentAutomatic"
            }
        }

        var allowsDebounce: Bool {
            self == .manual
        }

        var showsSuccessToast: Bool {
            self != .silentAutomatic
        }
    }

    private enum SteamSyncPolicy {
        static let debounceInterval: TimeInterval = 10 * 60
        static let automaticSilentSyncInterval: TimeInterval = 24 * 60 * 60
    }

    private(set) var state: LibraryState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((LibraryState) -> Void)?
    var onRoute: ((LibraryRoute) -> Void)?

    private let fetchLibraryOverviewUseCase: FetchLibraryOverviewUseCase
    private let fetchOwnedLibraryUseCase: FetchOwnedLibraryUseCase
    private let fetchRecentlyPlayedLibraryUseCase: FetchRecentlyPlayedLibraryUseCase
    private let fetchPlaytimeRecommendationsUseCase: FetchPlaytimeRecommendationsUseCase
    private let fetchLibraryFriendRecommendationsUseCase: FetchLibraryFriendRecommendationsUseCase
    private let fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase
    private let fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase
    private let startSteamLinkUseCase: StartSteamLinkUseCase
    private let unlinkSteamAccountUseCase: UnlinkSteamAccountUseCase
    private let syncOwnedSteamLibraryUseCase: SyncOwnedSteamLibraryUseCase
    private let updateLibraryGameStatusUseCase: UpdateLibraryGameStatusUseCase
    private let removeFavoriteUseCase: RemoveFavoriteUseCase
    private let translateTextUseCase: TranslateTextUseCase
    private let libraryCacheStore: LibraryCacheStore
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var fetchSequence = 0
    private var shouldForceOverviewReplacementAfterSteamSync = false
    private var isRefreshingSteamLinkStatus = false
    private var needsSteamLinkStatusRefresh = false
    private var shouldPresentSteamPrivacyGuidanceAfterSteamLink = false
    private var shouldPresentSteamConnectionOnboardingAfterSteamLink = false
    private var shouldEvaluateAutomaticSilentSteamSyncAfterNextOverviewLoad = false
    private var didTriggerInitialLoad = false

    init(
        fetchLibraryOverviewUseCase: FetchLibraryOverviewUseCase = FetchLibraryOverviewUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        fetchOwnedLibraryUseCase: FetchOwnedLibraryUseCase = FetchOwnedLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        fetchRecentlyPlayedLibraryUseCase: FetchRecentlyPlayedLibraryUseCase = FetchRecentlyPlayedLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        fetchPlaytimeRecommendationsUseCase: FetchPlaytimeRecommendationsUseCase = FetchPlaytimeRecommendationsUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        fetchLibraryFriendRecommendationsUseCase: FetchLibraryFriendRecommendationsUseCase = FetchLibraryFriendRecommendationsUseCase(
            libraryRepository: DefaultLibraryRepository(),
            friendRepository: DefaultFriendRepository()
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
        startSteamLinkUseCase: StartSteamLinkUseCase = StartSteamLinkUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        unlinkSteamAccountUseCase: UnlinkSteamAccountUseCase = UnlinkSteamAccountUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        syncOwnedSteamLibraryUseCase: SyncOwnedSteamLibraryUseCase = SyncOwnedSteamLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        updateLibraryGameStatusUseCase: UpdateLibraryGameStatusUseCase = UpdateLibraryGameStatusUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        initialTab: LibraryTab = .playing,
        removeFavoriteUseCase: RemoveFavoriteUseCase = RemoveFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        translateTextUseCase: TranslateTextUseCase = DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        ),
        libraryCacheStore: LibraryCacheStore = .shared
    ) {
        self.state = LibraryState(selectedTab: initialTab, pendingFocusSection: initialTab.focusedSection)
        self.fetchLibraryOverviewUseCase = fetchLibraryOverviewUseCase
        self.fetchOwnedLibraryUseCase = fetchOwnedLibraryUseCase
        self.fetchRecentlyPlayedLibraryUseCase = fetchRecentlyPlayedLibraryUseCase
        self.fetchPlaytimeRecommendationsUseCase = fetchPlaytimeRecommendationsUseCase
        self.fetchLibraryFriendRecommendationsUseCase = fetchLibraryFriendRecommendationsUseCase
        self.fetchFavoriteGamesUseCase = fetchFavoriteGamesUseCase
        self.fetchMyReviewedGamesUseCase = fetchMyReviewedGamesUseCase
        self.startSteamLinkUseCase = startSteamLinkUseCase
        self.unlinkSteamAccountUseCase = unlinkSteamAccountUseCase
        self.syncOwnedSteamLibraryUseCase = syncOwnedSteamLibraryUseCase
        self.updateLibraryGameStatusUseCase = updateLibraryGameStatusUseCase
        self.removeFavoriteUseCase = removeFavoriteUseCase
        self.translateTextUseCase = translateTextUseCase
        self.libraryCacheStore = libraryCacheStore
        observeLibraryChanges()
    }

    func send(_ intent: LibraryIntent) {
        switch intent {
        case .viewDidLoad:
            guard !didTriggerInitialLoad else {
                print("[Library] viewDidLoad ignored reason=initialLoadAlreadyTriggered")
                return
            }
            didTriggerInitialLoad = true
            shouldEvaluateAutomaticSilentSteamSyncAfterNextOverviewLoad = true

            let didRestoreCache = restoreCachedStateIfAvailable()
            if !didRestoreCache {
                apply(.setSections(makeLoadingSections()))
            }

            loadLibrary(trigger: didRestoreCache ? .refresh : .initial)

        case .pullToRefresh:
            loadLibrary(trigger: .refresh)

        case .didSelectPrimaryTab(let index):
            guard let selectedTab = LibraryTab(rawValue: index) else { return }
            guard selectedTab != state.selectedTab else {
                apply(.setSelectedTab(selectedTab))
                return
            }
            apply(.setSelectedTab(selectedTab))
            loadTask?.cancel()
            apply(.setLoading(false))
            apply(.setRefreshing(false))
            loadLibrary(trigger: .refresh)

        case .didSelectHighlightChip(let index):
            guard let selectedHighlightChip = LibraryHighlightChip(rawValue: index) else { return }
            guard selectedHighlightChip != state.selectedHighlightChip else {
                apply(.setSelectedHighlightChip(selectedHighlightChip))
                return
            }
            apply(.setSelectedHighlightChip(selectedHighlightChip))

        case .didSelectSort(let index):
            let selectedSort: LibrarySortOption = index == 1 ? .oldest : .latest
            guard selectedSort != state.selectedSort else { return }
            apply(.setSort(selectedSort))
            loadLibrary(trigger: .refresh)

        case .syncOwnedSteamLibraryButtonTapped:
            syncOwnedSteamLibrary(trigger: .manual)

        case .connectSteamButtonTapped:
            startSteamLink()

        case .steamPrivacyGuideButtonTapped:
            showSteamPrivacyGuide(reason: "manual")

        case .retrySteamPrivacyGuideTapped:
            retrySteamPrivacyGuidance()

        case .retrySteamSyncTapped:
            loadLibrary(trigger: .refresh)

        case .retryFriendRecommendationsTapped:
            loadLibrary(trigger: .refresh)

        case .retryPlaytimeRecommendationsTapped:
            loadLibrary(trigger: .refresh)

        case .unlinkSteamConfirmed:
            unlinkSteamAccount()

        case .didTapSteamLink:
            startSteamLink()

        case .didTapRecentlyPlayedGame(let identifier):
            routeToGameDetailIfPossible(identifier)

        case .didTapAddToPlaying(let identifier, _):
            addToPlaying(identifier)

        case .didTapWishlistGame(let identifier):
            routeToGameDetailIfPossible(identifier)

        case .didTapPlayingGame(let identifier):
            routeToGameDetailIfPossible(identifier)

        case .didTapPlaytimeRecommendationGame(let identifier):
            routeToGameDetailIfPossible(identifier)

        case .didTapFriendRecommendationGame(let identifier):
            routeToGameDetailIfPossible(identifier)

        case .didTapReviewedGame(let identifier):
            routeToGameDetailIfPossible(identifier)

        case .didTapSeeAllRecentlyPlayed:
            routeToRecentlyPlayedList()

        case .didTapSeeAllPlaying:
            routeToPlayingGamesList()

        case .didTapSeeAllOwned:
            routeToOwnedGamesList()

        case .didTapSeeAllWishlist:
            routeToLikedGamesList()

        case .didTapSeeAllReviewed:
            routeToWrittenReviewsList()

        case .didTapSeeAllFriendRecommendations:
            routeToFriendRecommendationsList()

        case .didTapSeeAllPlaytimeRecommendations:
            routeToPlaytimeRecommendationsList()

        case .didConfirmRemoveFavorite(let identifier):
            removeFavorite(identifier)

        case .didConsumeSuccessMessage:
            apply(.clearSuccessMessage)

        case .didConsumeSteamConnectionOnboarding:
            apply(.clearSteamConnectionOnboarding)

        case .didConsumeInitialFocus:
            apply(.consumeInitialFocus)
        }
    }

    private func apply(_ mutation: LibraryMutation) {
        state = LibraryReducer.reduce(state, mutation)
    }

    private func restoreCachedStateIfAvailable() -> Bool {
        guard let cachedState = libraryCacheStore.load() else {
            print("[LibraryCache] restore skipped reason=missing")
            return false
        }

        print(
            "[LibraryCache] restored " +
            "recentlyPlayedCount=\(cachedState.recentlyPlayed.count) " +
            "playingCount=\(cachedState.playingGames.count) " +
            "ownedCount=\(cachedState.ownedGames.count) " +
            "likedCount=\(cachedState.sections.first(where: { $0.kind == .wishlist })?.items.count ?? 0) " +
            "reviewsCount=\(cachedState.sections.first(where: { $0.kind == .reviewed })?.items.count ?? 0)"
        )

        apply(
            .setSteamState(
                steamLinkStatus: cachedSteamLinkStatus(from: cachedState),
                isConnected: cachedState.isSteamConnected,
                syncStatus: cachedState.steamSyncStatus,
                isSyncAvailable: cachedState.isSteamSyncAvailable,
                errorCode: cachedState.steamSyncErrorCode
            )
        )
        let restoredAt = Date()
        apply(.setPreviewGeneratedAt(restoredAt))
        apply(.setMergedRecentlyPlayedState(.snapshot, restoredAt))
        apply(
            .setLibraryItems(
                recentlyPlayed: cachedState.recentlyPlayed,
                playingGames: cachedState.playingGames,
                ownedGames: cachedState.ownedGames,
                backlogGames: cachedState.backlogGames,
                likedGames: state.likedGames,
                reviews: state.reviews
            )
        )
        refreshSummaryState()
        apply(.setPlaytimeRecommendations(cachedState.playtimeRecommendations))
        apply(
            .setFriendRecommendations(
                recommendations: cachedState.friendRecommendations,
                source: cachedState.friendRecommendationsSource,
                emptyState: cachedState.friendRecommendationsEmptyState
            )
        )
        apply(.setSections(cachedState.sections))
        return true
    }

    private func persistCurrentLibraryCache() {
        guard !state.sections.isEmpty else { return }

        libraryCacheStore.save(
            isSteamConnected: state.isSteamConnected,
            steamSyncStatus: state.steamSyncStatus,
            isSteamSyncAvailable: state.isSteamSyncAvailable,
            steamSyncErrorCode: state.steamSyncErrorCode,
            recentlyPlayed: state.recentlyPlayed,
            playingGames: state.playingGames,
            ownedGames: state.ownedGames,
            backlogGames: state.backlogGames,
            playtimeRecommendations: state.playtimeRecommendations,
            friendRecommendations: state.friendRecommendations,
            friendRecommendationsSource: state.friendRecommendationsSource,
            friendRecommendationsEmptyState: state.friendRecommendationsEmptyState,
            sections: state.sections
        )
    }

    private func makeLoadingSections() -> [LibrarySectionViewState] {
        LibrarySectionKind.displayOrder.map(makeLoadingSection)
    }

    private func makeLoadingSection(for kind: LibrarySectionKind) -> LibrarySectionViewState {
        let message: String
        switch kind {
        case .recentlyPlayed:
            message = "최근 플레이 정보를 불러오는 중..."
        case .playing:
            message = "플레이 중인 게임을 불러오는 중이에요."
        case .owned:
            message = "보유 게임 목록을 가져오는 중..."
        case .playtimeRecommendations:
            message = "플레이 성향 기반 추천을 불러오는 중이에요."
        case .friendRecommendations:
            message = "친구 기반 추천을 불러오는 중이에요."
        case .wishlist:
            message = "찜한 게임을 불러오는 중이에요."
        case .reviewed:
            message = "리뷰 작성함 목록을 불러오는 중이에요."
        }

        return LibrarySectionViewState(
            kind: kind,
            layoutStyle: .message,
            items: [
                .message(
                    LibraryMessageViewState(
                        id: "\(kind.title).loading",
                        style: .loading,
                        title: nil,
                        message: message,
                        detailText: nil,
                        buttonTitle: nil,
                        action: nil
                    )
                )
            ],
            showsSeeAll: false
        )
    }

    private func isLoadingSection(_ section: LibrarySectionViewState) -> Bool {
        guard section.items.count == 1,
              case .message(let messageViewState) = section.items[0] else {
            return false
        }

        return messageViewState.style == .loading
    }

    private func replacingSection(
        _ section: LibrarySectionViewState,
        in currentSections: [LibrarySectionViewState]
    ) -> [LibrarySectionViewState] {
        var sectionsByKind = Dictionary(uniqueKeysWithValues: currentSections.map { ($0.kind, $0) })
        sectionsByKind[section.kind] = section
        return LibrarySectionKind.displayOrder.compactMap { sectionsByKind[$0] }
    }

    private func shouldPreserveCurrentSection(
        kind: LibrarySectionKind,
        trigger: LoadTrigger,
        preserveCurrentSectionOnFailure: Bool
    ) -> Bool {
        guard preserveCurrentSectionOnFailure, trigger == .refresh else { return false }
        guard let currentSection = state.sections.first(where: { $0.kind == kind }) else { return false }
        return !isLoadingSection(currentSection)
    }

    @MainActor
    private func applyOverviewResult(
        _ result: Result<LibraryOverview, Error>,
        trigger: LoadTrigger,
        previousSteamState: (
            steamLinkStatus: SteamLinkStatus,
            isConnected: Bool,
            syncStatus: SteamSyncStatus,
            isSyncAvailable: Bool,
            errorCode: String?
        ),
        preserveCurrentSectionOnFailure: Bool
    ) {
        let baseSections = state.sections.isEmpty ? makeLoadingSections() : state.sections
        let steamState = resolvedMergedSteamState(from: result, fallback: previousSteamState)
        let shouldUpdateRecentlyPlayed = state.selectedTab == .playing || shouldForceOverviewReplacementAfterSteamSync

        apply(
            .setSteamState(
                steamLinkStatus: steamState.steamLinkStatus,
                isConnected: steamState.isConnected,
                syncStatus: steamState.syncStatus,
                isSyncAvailable: steamState.isSyncAvailable,
                errorCode: steamState.errorCode
            )
        )

        switch result {
        case .success(let overview):
            var serverSummaryByTab = state.serverSummaryByTab
            if let playingSummary = overview.playingSummary {
                serverSummaryByTab[.playing] = playingSummary
            }
            if let favoritesSummary = overview.favoritesSummary {
                serverSummaryByTab[.favorites] = favoritesSummary
            }
            if let reviewedSummary = overview.reviewedSummary {
                serverSummaryByTab[.reviewed] = reviewedSummary
            }
            apply(.setServerSummaryByTab(serverSummaryByTab))

            let mergedRecentlyPlayed = shouldUpdateRecentlyPlayed
                ? mergeRecentlyPlayed(current: state.recentlyPlayed, incoming: overview.recentlyPlayed)
                : state.recentlyPlayed
            let mergedOwnedCollection = mergeOwnedCollection(
                currentOwned: state.ownedGames,
                currentBacklog: state.backlogGames,
                incomingOwned: overview.owned,
                incomingBacklog: overview.backlog
            )
            let resolvedOverview = LibraryOverview(
                steamLinkStatus: steamState.steamLinkStatus,
                steamSyncStatus: overview.steamSyncStatus,
                isSteamSyncAvailable: overview.isSteamSyncAvailable,
                steamSyncErrorCode: overview.steamSyncErrorCode,
                recentlyPlayed: mergedRecentlyPlayed,
                playing: overview.playing,
                owned: mergedOwnedCollection.owned,
                backlog: mergedOwnedCollection.backlog,
                playingSummary: overview.playingSummary,
                favoritesSummary: overview.favoritesSummary,
                reviewedSummary: overview.reviewedSummary
            )

            if !overview.owned.isEmpty || !overview.steamLinkStatus.isLinked {
                apply(.setSteamOwnedSyncErrorCode(nil))
            }
            apply(
                .setLibraryItems(
                    recentlyPlayed: resolvedOverview.recentlyPlayed,
                    playingGames: resolvedOverview.playing,
                    ownedGames: resolvedOverview.owned,
                    backlogGames: resolvedOverview.backlog,
                    likedGames: state.likedGames,
                    reviews: state.reviews
                )
            )
            let fullGeneratedAt = Date()
            if shouldReplaceWithIncomingFullState(generatedAt: fullGeneratedAt) {
                apply(.setFullGeneratedAt(fullGeneratedAt))
                if shouldUpdateRecentlyPlayed {
                    apply(.setMergedRecentlyPlayedState(.full, fullGeneratedAt))
                }
            }
            refreshSummaryState(for: .playing)

            let playingIdentifiers = Set(resolvedOverview.playing.map(\.identifier))
            let sectionsToUpdate: [LibrarySectionViewState] = {
                if shouldUpdateRecentlyPlayed {
                    return [
                        makeRecentlyPlayedSection(from: .success(resolvedOverview), playingIdentifiers: playingIdentifiers),
                        makePlayingSection(from: .success(resolvedOverview)),
                        makeOwnedSection(from: .success(resolvedOverview))
                    ]
                }
                return [
                    makePlayingSection(from: .success(resolvedOverview)),
                    makeOwnedSection(from: .success(resolvedOverview))
                ]
            }()

            let updatedSections = sectionsToUpdate.reduce(baseSections) { sections, section in
                replacingSection(section, in: sections)
            }

            apply(.setSections(updatedSections))
            maybeTriggerAutomaticSilentSteamSyncIfNeeded(
                overview: overview,
                trigger: trigger
            )
            shouldForceOverviewReplacementAfterSteamSync = false

        case .failure:
            guard shouldUpdateRecentlyPlayed || shouldPreserveCurrentSection(
                kind: .recentlyPlayed,
                trigger: trigger,
                preserveCurrentSectionOnFailure: preserveCurrentSectionOnFailure
            ) == false else {
                let updatedSections = [
                    makePlayingSection(from: result),
                    makeOwnedSection(from: result)
                ].reduce(baseSections) { sections, section in
                    replacingSection(section, in: sections)
                }

                apply(.setSections(updatedSections))
                return
            }

            let sectionsToUpdate: [LibrarySectionViewState] = {
                if shouldUpdateRecentlyPlayed {
                    return [
                        makeRecentlyPlayedSection(from: result, playingIdentifiers: []),
                        makePlayingSection(from: result),
                        makeOwnedSection(from: result)
                    ]
                }
                return [
                    makePlayingSection(from: result),
                    makeOwnedSection(from: result)
                ]
            }()

            let updatedSections = sectionsToUpdate.reduce(baseSections) { sections, section in
                replacingSection(section, in: sections)
            }

            apply(.setSections(updatedSections))
            shouldForceOverviewReplacementAfterSteamSync = false
        }
    }

    @MainActor
    private func applyWishlistResult(
        _ result: Result<[FavoriteGameEntry], Error>,
        trigger: LoadTrigger,
        preserveCurrentSectionOnFailure: Bool
    ) {
        if case .success(let wishlist) = result {
            apply(
                .setLibraryItems(
                    recentlyPlayed: state.recentlyPlayed,
                    playingGames: state.playingGames,
                    ownedGames: state.ownedGames,
                    backlogGames: state.backlogGames,
                    likedGames: wishlist.map(\.game),
                    reviews: state.reviews
                )
            )
            refreshSummaryState(for: .favorites)
        } else if shouldPreserveCurrentSection(
            kind: .wishlist,
            trigger: trigger,
            preserveCurrentSectionOnFailure: preserveCurrentSectionOnFailure
        ) {
            return
        }

        let baseSections = state.sections.isEmpty ? makeLoadingSections() : state.sections
        let updatedSection = makeWishlistSection(from: result)
        apply(.setSections(replacingSection(updatedSection, in: baseSections)))
    }

    @MainActor
    private func applyFriendRecommendationsResult(
        _ result: Result<LibraryFriendRecommendationsResult, Error>,
        trigger: LoadTrigger,
        preserveCurrentSectionOnFailure: Bool
    ) {
        if case .success(let recommendations) = result {
            apply(
                .setFriendRecommendations(
                    recommendations: recommendations.recommendations,
                    source: recommendations.source,
                    emptyState: recommendations.emptyState
                )
            )
        } else if shouldPreserveCurrentSection(
            kind: .friendRecommendations,
            trigger: trigger,
            preserveCurrentSectionOnFailure: preserveCurrentSectionOnFailure
        ) {
            return
        }

        let baseSections = state.sections.isEmpty ? makeLoadingSections() : state.sections
        let updatedSection = makeFriendRecommendationsSection(from: result)
        apply(.setSections(replacingSection(updatedSection, in: baseSections)))
    }

    @MainActor
    private func applyPlaytimeRecommendationsResult(
        _ result: Result<[PlaytimeRecommendation], Error>,
        trigger: LoadTrigger,
        preserveCurrentSectionOnFailure: Bool
    ) {
        if case .success(let recommendations) = result {
            apply(.setPlaytimeRecommendations(recommendations))
        } else if shouldPreserveCurrentSection(
            kind: .playtimeRecommendations,
            trigger: trigger,
            preserveCurrentSectionOnFailure: preserveCurrentSectionOnFailure
        ) {
            return
        }

        let baseSections = state.sections.isEmpty ? makeLoadingSections() : state.sections
        let updatedSection = makePlaytimeRecommendationsSection(from: result)
        apply(.setSections(replacingSection(updatedSection, in: baseSections)))
    }

    @MainActor
    private func applyReviewedResult(
        _ result: Result<[ReviewedGame], Error>,
        trigger: LoadTrigger,
        preserveCurrentSectionOnFailure: Bool
    ) {
        if case .success(let reviewedGames) = result {
            apply(
                .setLibraryItems(
                    recentlyPlayed: state.recentlyPlayed,
                    playingGames: state.playingGames,
                    ownedGames: state.ownedGames,
                    backlogGames: state.backlogGames,
                    likedGames: state.likedGames,
                    reviews: reviewedGames
                )
            )
            refreshSummaryState(for: .reviewed)
        } else if shouldPreserveCurrentSection(
            kind: .reviewed,
            trigger: trigger,
            preserveCurrentSectionOnFailure: preserveCurrentSectionOnFailure
        ) {
            return
        }

        let baseSections = state.sections.isEmpty ? makeLoadingSections() : state.sections
        let updatedSection = makeReviewedSection(from: result)
        apply(.setSections(replacingSection(updatedSection, in: baseSections)))
    }

    @MainActor
    private func applyOwnedCollectionRefreshResult(
        _ result: Result<OwnedLibraryCollection, Error>
    ) {
        guard case .success(let collection) = result else { return }

        let mergedCollection = mergeOwnedCollection(
            currentOwned: state.ownedGames,
            currentBacklog: state.backlogGames,
            incomingOwned: collection.owned,
            incomingBacklog: collection.backlog
        )
        apply(
            .setLibraryItems(
                recentlyPlayed: state.recentlyPlayed,
                playingGames: state.playingGames,
                ownedGames: mergedCollection.owned,
                backlogGames: mergedCollection.backlog,
                likedGames: state.likedGames,
                reviews: state.reviews
            )
        )
        refreshSummaryState(for: .playing)

        let overview = currentOverview(
            recentlyPlayed: state.recentlyPlayed,
            playingGames: state.playingGames,
            ownedGames: mergedCollection.owned,
            backlogGames: mergedCollection.backlog
        )
        let updatedSections = [
            makeOwnedSection(from: .success(overview))
        ].reduce(state.sections.isEmpty ? makeLoadingSections() : state.sections) { sections, section in
            replacingSection(section, in: sections)
        }
        apply(.setSections(updatedSections))
    }

    @MainActor
    private func applyRecentlyPlayedRefreshResult(
        _ result: Result<[LibraryGameSummary], Error>
    ) {
        guard case .success(let summaries) = result else { return }

        let mergedRecentlyPlayed = mergeRecentlyPlayed(current: state.recentlyPlayed, incoming: summaries)
        let generatedAt = Date()
        guard shouldReplaceWithIncomingFullState(generatedAt: generatedAt) else { return }

        apply(
            .setLibraryItems(
                recentlyPlayed: mergedRecentlyPlayed,
                playingGames: state.playingGames,
                ownedGames: state.ownedGames,
                backlogGames: state.backlogGames,
                likedGames: state.likedGames,
                reviews: state.reviews
            )
        )
        apply(.setFullGeneratedAt(generatedAt))
        apply(.setMergedRecentlyPlayedState(.full, generatedAt))
        refreshSummaryState(for: .playing)

        let overview = currentOverview(
            recentlyPlayed: mergedRecentlyPlayed,
            playingGames: state.playingGames,
            ownedGames: state.ownedGames,
            backlogGames: state.backlogGames
        )
        let updatedSections = [
            makeRecentlyPlayedSection(
                from: .success(overview),
                playingIdentifiers: Set(state.playingGames.map(\.identifier))
            )
        ].reduce(state.sections.isEmpty ? makeLoadingSections() : state.sections) { sections, section in
            replacingSection(section, in: sections)
        }
        apply(.setSections(updatedSections))
    }

    private func maybeTriggerAutomaticSilentSteamSyncIfNeeded(
        overview: LibraryOverview,
        trigger: LoadTrigger
    ) {
        guard shouldEvaluateAutomaticSilentSteamSyncAfterNextOverviewLoad else { return }
        shouldEvaluateAutomaticSilentSteamSyncAfterNextOverviewLoad = false

        guard overview.steamLinkStatus.isLinked else {
            print("[Library] automaticSteamSync skipped reason=steamNotConnected trigger=\(trigger.logName)")
            return
        }

        guard shouldTriggerAutomaticSilentSteamSync(now: Date()) else {
            print("[Library] automaticSteamSync skipped reason=recentlyAttempted trigger=\(trigger.logName)")
            return
        }

        print("[Library] automaticSteamSync started trigger=\(trigger.logName)")
        syncOwnedSteamLibrary(trigger: .silentAutomatic)
    }

    private func shouldTriggerAutomaticSilentSteamSync(now: Date) -> Bool {
        let lastAttemptDate = libraryCacheStore.loadLastAttemptedSteamSyncDate()
        let lastSuccessfulDate = libraryCacheStore.loadLastSuccessfulSteamSyncDate()
        let referenceDate = [lastAttemptDate, lastSuccessfulDate].compactMap { $0 }.max()

        guard let referenceDate else { return true }
        return now.timeIntervalSince(referenceDate) >= SteamSyncPolicy.automaticSilentSyncInterval
    }

    private func loadLibrary(trigger: LoadTrigger) {
        guard !state.isLoading && !state.isRefreshing else {
            print("[Library] fetchSkipped trigger=\(trigger.logName) reason=requestInFlight")
            return
        }

        loadTask?.cancel()
        apply(.clearError)

        if trigger == .initial && state.sections.isEmpty {
            apply(.setSections(makeLoadingSections()))
        }

        switch trigger {
        case .initial:
            apply(.setLoading(true))
        case .refresh:
            apply(.setRefreshing(true))
        }

        let selectedSort = state.selectedSort
        let requestedTab = state.selectedTab
        let isSteamConnected = state.isSteamConnected
        fetchSequence += 1
        let fetchID = fetchSequence
        print(
            "[Library] fetchStarted id=\(fetchID) trigger=\(trigger.logName) " +
            "sort=\(selectedSort) tab=\(requestedTab)"
        )
        let previousSteamState = (
            steamLinkStatus: state.steamLinkStatus,
            isConnected: state.isSteamConnected,
            syncStatus: state.steamSyncStatus,
            isSyncAvailable: state.isSteamSyncAvailable,
            errorCode: state.steamSyncErrorCode
        )
        let hadVisibleSectionsBeforeLoad = state.sections.contains(where: { !isLoadingSection($0) })
        loadTask = Task { [weak self] in
            guard let self else { return }

            var overviewResult: Result<LibraryOverview, Error>?
            var playtimeRecommendationsResult: Result<[PlaytimeRecommendation], Error>?
            var friendRecommendationsResult: Result<LibraryFriendRecommendationsResult, Error>?
            var wishlistResult: Result<[FavoriteGameEntry], Error>?
            var reviewedResult: Result<[ReviewedGame], Error>?

            await withTaskGroup(of: SectionLoadEvent.self) { group in
                group.addTask { [weak self] in
                    guard let self else { return .overview(.failure(CancellationError())) }
                    let rawResult = await self.captureResult {
                        try await self.fetchLibraryOverviewUseCase.execute(sort: selectedSort.userGameSort)
                    }
                    return .overview(await self.translatedOverview(from: rawResult))
                }

                group.addTask { [weak self] in
                    guard let self else { return .playtimeRecommendations(.failure(CancellationError())) }
                    let rawResult: Result<[PlaytimeRecommendation], Error>
                    if isSteamConnected {
                        rawResult = await self.captureResult {
                            try await self.fetchPlaytimeRecommendationsUseCase.execute()
                        }
                    } else {
                        rawResult = .success([])
                    }
                    return .playtimeRecommendations(
                        await self.translatedPlaytimeRecommendations(from: rawResult)
                    )
                }

                group.addTask { [weak self] in
                    guard let self else { return .friendRecommendations(.failure(CancellationError())) }
                    let rawResult = await self.captureResult {
                        try await self.fetchLibraryFriendRecommendationsUseCase.execute(
                            isSteamConnected: isSteamConnected
                        )
                    }
                    return .friendRecommendations(
                        await self.translatedFriendRecommendations(from: rawResult)
                    )
                }

                group.addTask { [weak self] in
                    guard let self else { return .wishlist(.failure(CancellationError())) }
                    let rawResult = await self.captureResult {
                        try await self.fetchFavoriteGamesUseCase.execute(sort: selectedSort.favoriteSort)
                    }
                    return .wishlist(await self.translatedWishlist(from: rawResult))
                }

                group.addTask { [weak self] in
                    guard let self else { return .reviewed(.failure(CancellationError())) }
                    let rawResult = await self.captureResult {
                        try await self.fetchMyReviewedGamesUseCase.execute(sort: selectedSort.reviewSort)
                    }
                    return .reviewed(await self.translatedReviewed(from: rawResult))
                }

                for await event in group {
                    if Task.isCancelled { return }

                    switch event {
                    case .overview(let result):
                        overviewResult = result
                        self.logSectionResponseArrived(
                            id: fetchID,
                            section: "overview",
                            result: result
                        )

                        await MainActor.run {
                            guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "overview") else { return }
                            self.applyOverviewResult(
                                result,
                                trigger: trigger,
                                previousSteamState: previousSteamState,
                                preserveCurrentSectionOnFailure: hadVisibleSectionsBeforeLoad
                            )
                        }

                    case .playtimeRecommendations(let result):
                        playtimeRecommendationsResult = result
                        self.logSectionResponseArrived(
                            id: fetchID,
                            section: "playtimeRecommendations",
                            result: result
                        )

                        await MainActor.run {
                            guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "playtimeRecommendations") else { return }
                            self.applyPlaytimeRecommendationsResult(
                                result,
                                trigger: trigger,
                                preserveCurrentSectionOnFailure: hadVisibleSectionsBeforeLoad
                            )
                        }

                    case .friendRecommendations(let result):
                        friendRecommendationsResult = result
                        self.logSectionResponseArrived(
                            id: fetchID,
                            section: "friendRecommendations",
                            result: result
                        )

                        await MainActor.run {
                            guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "friendRecommendations") else { return }
                            self.applyFriendRecommendationsResult(
                                result,
                                trigger: trigger,
                                preserveCurrentSectionOnFailure: hadVisibleSectionsBeforeLoad
                            )
                        }

                    case .wishlist(let result):
                        wishlistResult = result
                        self.logSectionResponseArrived(
                            id: fetchID,
                            section: "wishlist",
                            result: result
                        )

                        await MainActor.run {
                            guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "wishlist") else { return }
                            self.applyWishlistResult(
                                result,
                                trigger: trigger,
                                preserveCurrentSectionOnFailure: hadVisibleSectionsBeforeLoad
                            )
                        }

                    case .reviewed(let result):
                        reviewedResult = result
                        self.logSectionResponseArrived(
                            id: fetchID,
                            section: "reviewed",
                            result: result
                        )

                        await MainActor.run {
                            guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "reviewed") else { return }
                            self.applyReviewedResult(
                                result,
                                trigger: trigger,
                                preserveCurrentSectionOnFailure: hadVisibleSectionsBeforeLoad
                            )
                        }
                    }
                }
            }

            guard let resolvedOverviewResult = overviewResult,
                  let resolvedPlaytimeRecommendationsResult = playtimeRecommendationsResult,
                  let resolvedFriendRecommendationsResult = friendRecommendationsResult,
                  let resolvedWishlistResult = wishlistResult,
                  let resolvedReviewedResult = reviewedResult,
                  !Task.isCancelled else {
                return
            }

            self.logResponseSummary(
                id: fetchID,
                overviewResult: resolvedOverviewResult,
                playtimeRecommendationsResult: resolvedPlaytimeRecommendationsResult,
                friendRecommendationsResult: resolvedFriendRecommendationsResult,
                wishlistResult: resolvedWishlistResult,
                reviewedResult: resolvedReviewedResult
            )

            let errorMessage = self.resolveErrorMessage(
                overviewResult: resolvedOverviewResult,
                playtimeRecommendationsResult: resolvedPlaytimeRecommendationsResult,
                friendRecommendationsResult: resolvedFriendRecommendationsResult,
                wishlistResult: resolvedWishlistResult,
                reviewedResult: resolvedReviewedResult
            )
            let steamState = self.resolveSteamState(
                from: resolvedOverviewResult,
                fallback: previousSteamState
            )
            let shouldPersistCache = [
                resolvedOverviewResult.isSuccess,
                resolvedPlaytimeRecommendationsResult.isSuccess,
                resolvedFriendRecommendationsResult.isSuccess,
                resolvedWishlistResult.isSuccess,
                resolvedReviewedResult.isSuccess
            ].contains(true)

            await MainActor.run {
                guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "finalize") else { return }
                self.logCurrentMappedState(id: fetchID)
                self.apply(.clearAddingToPlaying)
                self.apply(.setLoading(false))
                self.apply(.setRefreshing(false))
                if let errorMessage {
                    self.apply(.setError(errorMessage))
                } else {
                    self.apply(.clearError)
                }

                if shouldPersistCache {
                    self.persistCurrentLibraryCache()
                }

                if self.isRefreshingSteamLinkStatus {
                    print("[SteamLink] statusRefreshCompleted")
                    self.isRefreshingSteamLinkStatus = false
                }

                if self.needsSteamLinkStatusRefresh {
                    self.needsSteamLinkStatusRefresh = false
                    self.refreshSteamLinkStatus()
                }

                self.maybePresentSteamPrivacyGuidanceAfterSteamLink(
                    steamState: steamState
                )
            }
        }
    }

    @MainActor
    private func shouldAcceptResponse(fetchID: Int, requestedTab: LibraryTab, section: String) -> Bool {
        guard fetchID == fetchSequence else {
            print("[Library] responseIgnored id=\(fetchID) section=\(section) reason=staleFetch latest=\(fetchSequence)")
            return false
        }

        guard requestedTab == state.selectedTab else {
            print(
                "[Library] responseIgnored id=\(fetchID) section=\(section) " +
                "reason=tabMismatch requested=\(requestedTab) current=\(state.selectedTab)"
            )
            return false
        }

        return true
    }

    private func refreshSummaryState() {
        apply(.setSummaryByTab(makeSummaryByTab(for: state)))
    }

    private func refreshSummaryState(for tab: LibraryTab) {
        var summaryByTab = state.summaryByTab
        summaryByTab[tab] = makeSummaryState(for: tab, from: state)
        apply(.setSummaryByTab(summaryByTab))
    }

    private func shouldReplaceWithIncomingFullState(generatedAt: Date) -> Bool {
        if let currentGeneratedAt = state.mergedGeneratedAt, generatedAt < currentGeneratedAt {
            print("[Library] mergedStateIgnored reason=olderGeneratedAt incoming=\(generatedAt.timeIntervalSince1970) current=\(currentGeneratedAt.timeIntervalSince1970)")
            return false
        }
        return true
    }

    private func mergeRecentlyPlayed(
        current: [LibraryGameSummary],
        incoming: [LibraryGameSummary]
    ) -> [LibraryGameSummary] {
        guard !(incoming.isEmpty && !current.isEmpty) else {
            print(
                "[Library] recentlyPlayedMerge keptCurrent " +
                "reason=incomingEmpty currentCount=\(current.count)"
            )
            return current
        }

        guard incoming.count >= current.count else {
            print(
                "[Library] recentlyPlayedMerge keptCurrent " +
                "reason=currentHasMoreItems currentCount=\(current.count) incomingCount=\(incoming.count)"
            )
            return current
        }

        let currentByIdentifier = Dictionary(uniqueKeysWithValues: current.map { ($0.identifier, $0) })
        return incoming.map { incomingSummary in
            guard let currentSummary = currentByIdentifier[incomingSummary.identifier] else { return incomingSummary }

            let resolvedLastPlayedAt: Date?
            let resolvedLastPlayedAtSource: String?
            let resolvedHasReliableLastPlayedAt: Bool
            if incomingSummary.hasReliableLastPlayedAt, let incomingLastPlayedAt = incomingSummary.lastPlayedAt {
                resolvedLastPlayedAt = incomingLastPlayedAt
                resolvedLastPlayedAtSource = incomingSummary.lastPlayedAtSource
                resolvedHasReliableLastPlayedAt = true
            } else {
                resolvedLastPlayedAt = currentSummary.lastPlayedAt
                resolvedLastPlayedAtSource = currentSummary.lastPlayedAtSource
                resolvedHasReliableLastPlayedAt = currentSummary.hasReliableLastPlayedAt
            }

            let resolvedRecentPlaytimeMinutes = incomingSummary.recentPlaytimeMinutes ?? currentSummary.recentPlaytimeMinutes
            let resolvedRecentPlaytimeText = incomingSummary.recentPlaytimeText ?? currentSummary.recentPlaytimeText
            let resolvedFallbackReason = incomingSummary.recentPlayFallbackReason ?? currentSummary.recentPlayFallbackReason

            return incomingSummary.replacingRecentPlayMetadata(
                recentPlaytimeMinutes: resolvedRecentPlaytimeMinutes,
                recentPlaytimeText: resolvedRecentPlaytimeText,
                lastPlayedAt: resolvedLastPlayedAt,
                lastPlayedAtSource: resolvedLastPlayedAtSource,
                hasReliableLastPlayedAt: resolvedHasReliableLastPlayedAt,
                recentPlayFallbackReason: resolvedFallbackReason
            )
        }
    }

    private func mergeOwnedCollection(
        currentOwned: [LibraryGameSummary],
        currentBacklog: [LibraryGameSummary],
        incomingOwned: [LibraryGameSummary],
        incomingBacklog: [LibraryGameSummary]
    ) -> (owned: [LibraryGameSummary], backlog: [LibraryGameSummary]) {
        let owned = incomingOwned.isEmpty && !currentOwned.isEmpty ? currentOwned : incomingOwned
        let backlog = incomingBacklog.isEmpty && !currentBacklog.isEmpty ? currentBacklog : incomingBacklog
        return (owned, backlog)
    }

    private func resolvedMergedSteamState(
        from result: Result<LibraryOverview, Error>,
        fallback: (
            steamLinkStatus: SteamLinkStatus,
            isConnected: Bool,
            syncStatus: SteamSyncStatus,
            isSyncAvailable: Bool,
            errorCode: String?
        )
    ) -> (
        steamLinkStatus: SteamLinkStatus,
        isConnected: Bool,
        syncStatus: SteamSyncStatus,
        isSyncAvailable: Bool,
        errorCode: String?
    ) {
        let resolvedSteamState = resolveSteamState(from: result, fallback: fallback)
        guard case .success(let overview) = result else { return resolvedSteamState }

        let shouldPreserveConnectedState =
            fallback.isConnected
            && !state.isUnlinkingSteamAccount
            && !resolvedSteamState.isConnected
            && overview.recentlyPlayed.isEmpty
            && overview.owned.isEmpty
            && overview.backlog.isEmpty

        guard shouldPreserveConnectedState else { return resolvedSteamState }

        print("[Library] steamStateMerge keptConnectedState reason=emptyIncomingOverview")
        return fallback
    }

    private func cachedSteamLinkStatus(from cachedState: LibraryCachedState) -> SteamLinkStatus {
        guard cachedState.isSteamConnected else { return .notLinked }
        return SteamLinkStatus(
            connectionState: .linked,
            steamID: state.steamLinkStatus.steamID,
            displayName: state.steamLinkStatus.displayName,
            personaName: state.steamLinkStatus.personaName,
            profileURL: state.steamLinkStatus.profileURL,
            canSync: cachedState.isSteamSyncAvailable,
            canDisconnect: state.steamLinkStatus.canDisconnect,
            lastSteamSyncAt: state.steamLinkStatus.lastSteamSyncAt
        )
    }

    private func currentOverview(
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        ownedGames: [LibraryGameSummary],
        backlogGames: [LibraryGameSummary]
    ) -> LibraryOverview {
        LibraryOverview(
            steamLinkStatus: state.steamLinkStatus,
            steamSyncStatus: state.steamSyncStatus,
            isSteamSyncAvailable: state.isSteamSyncAvailable,
            steamSyncErrorCode: state.steamSyncErrorCode,
            recentlyPlayed: recentlyPlayed,
            playing: playingGames,
            owned: ownedGames,
            backlog: backlogGames,
            playingSummary: state.serverSummaryByTab[.playing],
            favoritesSummary: state.serverSummaryByTab[.favorites],
            reviewedSummary: state.serverSummaryByTab[.reviewed]
        )
    }

    private func makeSummaryByTab(for state: LibraryState) -> [LibraryTab: LibraryTabSummaryState] {
        [
            .playing: makePlayingSummaryState(from: state),
            .favorites: makeFavoritesSummaryState(from: state),
            .reviewed: makeReviewedSummaryState(from: state)
        ]
    }

    private func makeSummaryState(
        for tab: LibraryTab,
        from state: LibraryState
    ) -> LibraryTabSummaryState {
        switch tab {
        case .playing:
            return makePlayingSummaryState(from: state)
        case .favorites:
            return makeFavoritesSummaryState(from: state)
        case .reviewed:
            return makeReviewedSummaryState(from: state)
        }
    }

    private func makePlayingSummaryState(from state: LibraryState) -> LibraryTabSummaryState {
        let summaries = uniqueSummaries(
            state.recentlyPlayed + state.playingGames + state.ownedGames
        )
        let totalMinutes = summaries
            .compactMap { $0.playtimeMinutes ?? $0.recentPlaytimeMinutes }
            .reduce(0, +)
        let ratings = summaries.compactMap { summary -> Double? in
            guard let rating = summary.rating, rating.isFinite, rating > 0 else { return nil }
            return rating
        }
        let derivedPrimaryValue = max(Double(totalMinutes) / 60, 0)
        let derivedAverageRating = averageRating(from: ratings)
        let derivedGameCount = summaries.count
        let derivedReviewCount = ratings.count

        if let serverSummary = state.serverSummaryByTab[.playing], serverSummary.hasRenderableValues {
            let resolvedPrimaryValue = serverSummary.totalPlaytimeHours ?? derivedPrimaryValue
            let resolvedGameCount = serverSummary.gameCount ?? derivedGameCount
            let resolvedAverageRating = serverSummary.averageRating ?? derivedAverageRating
            let resolvedReviewCount = serverSummary.reviewCount ?? derivedReviewCount
            let fallbackTriggered = serverSummary.totalPlaytimeHours == nil || serverSummary.gameCount == nil

            print(
                "[LibrarySummary] " +
                "selectedTab=\(LibraryTab.playing) " +
                "gameCount=\(resolvedGameCount) " +
                "totalPlaytimeHours=\(resolvedPrimaryValue) " +
                "source=server.preview.summary " +
                "source.gameCount=\(serverSummary.gameCountSourceField ?? "server.nil") " +
                "source.totalPlaytimeHours=\(serverSummary.totalPlaytimeHoursSourceField ?? "server.nil") " +
                "fallbackTriggered=\(fallbackTriggered)"
            )

            return LibraryTabSummaryState(
                primaryTitle: "총 플레이",
                primaryValue: resolvedPrimaryValue,
                primaryValueKind: .hours,
                averageRating: resolvedAverageRating,
                gameCount: resolvedGameCount,
                reviewCount: resolvedReviewCount,
                sourceDescription: "server.preview.summary"
            )
        }

        print(
            "[LibrarySummary] " +
            "selectedTab=\(LibraryTab.playing) " +
            "gameCount=\(derivedGameCount) " +
            "totalPlaytimeHours=\(derivedPrimaryValue) " +
            "source.gameCount=derived.uniqueSummaries " +
            "source.totalPlaytimeHours=derived.playtimeMinutes " +
            "fallbackTriggered=true"
        )

        return LibraryTabSummaryState(
            primaryTitle: "총 플레이",
            primaryValue: derivedPrimaryValue,
            primaryValueKind: .hours,
            averageRating: derivedAverageRating,
            gameCount: derivedGameCount,
            reviewCount: derivedReviewCount,
            sourceDescription: "derived.playingCollections"
        )
    }

    private func makeFavoritesSummaryState(from state: LibraryState) -> LibraryTabSummaryState {
        let uniqueLikedGames = uniqueGames(state.likedGames)
        let ratings = uniqueLikedGames.compactMap { game -> Double? in
            guard game.rating.isFinite, game.rating > 0 else { return nil }
            return game.rating
        }

        return LibraryTabSummaryState(
            primaryTitle: "찜한 게임",
            primaryValue: Double(uniqueLikedGames.count),
            primaryValueKind: .count,
            averageRating: averageRating(from: ratings),
            gameCount: uniqueLikedGames.count,
            reviewCount: ratings.count,
            sourceDescription: "derived.likedGames"
        )
    }

    private func makeReviewedSummaryState(from state: LibraryState) -> LibraryTabSummaryState {
        let reviewCount = state.reviews.count
        let ratings = state.reviews.compactMap { review -> Double? in
            guard review.rating.isFinite, review.rating > 0 else { return nil }
            return review.rating
        }
        let uniqueReviewedGameCount = Set(state.reviews.map(\.gameId)).count

        return LibraryTabSummaryState(
            primaryTitle: "작성한 리뷰",
            primaryValue: Double(reviewCount),
            primaryValueKind: .count,
            averageRating: reviewCount == 0 ? nil : averageRating(from: ratings),
            gameCount: uniqueReviewedGameCount,
            reviewCount: reviewCount,
            sourceDescription: "derived.reviews"
        )
    }

    private func averageRating(from ratings: [Double]) -> Double? {
        let finiteRatings = ratings.filter(\.isFinite)
        guard !finiteRatings.isEmpty else { return nil }
        return finiteRatings.reduce(0, +) / Double(finiteRatings.count)
    }

    private func uniqueSummaries(_ summaries: [LibraryGameSummary]) -> [LibraryGameSummary] {
        var seenKeys = Set<String>()
        return summaries.filter { summary in
            seenKeys.insert(summary.identifier.uniqueKey).inserted
        }
    }

    private func uniqueGames(_ games: [Game]) -> [Game] {
        var seenIDs = Set<Int>()
        return games.filter { game in
            seenIDs.insert(game.id).inserted
        }
    }

    private func routeToGameDetailIfPossible(_ identifier: LibraryGameIdentifier) {
        if let summary = libraryGameSummary(for: identifier) {
            if let destination = detailDestination(for: summary) {
                route(to: destination)
                return
            }

            print(
                "[Library] detailUnavailable " +
                "identifier=\(identifier.uniqueKey) " +
                "enrichmentStatus=\(summary.enrichmentStatus.rawValue)"
            )
            apply(.clearError)
            apply(.setError("게임 상세 정보를 아직 불러올 수 없어요."))
            return
        }

        guard let gameID = identifier.detailGameID else {
            print("[Library] detailUnavailable identifier=\(identifier.uniqueKey)")
            apply(.clearError)
            apply(.setError("게임 상세 정보를 아직 불러올 수 없어요."))
            return
        }

        print("[Library] detailRoute source=igdb gameId=\(gameID)")
        onRoute?(.showGameDetail(gameID))
    }

    private func route(to destination: LibraryGameDetailDestination) {
        switch destination {
        case .igdb(let gameID):
            print("[Library] detailRoute source=igdb gameId=\(gameID)")
            onRoute?(.showGameDetail(gameID))
        case .steamFallback(let viewState):
            print(
                "[Library] detailRoute source=steam " +
                "externalGameId=\(viewState.externalGameId) " +
                "matchStatus=\(viewState.matchStatus.rawValue) " +
                "enrichmentStatus=\(viewState.enrichmentStatus.rawValue)"
            )
            onRoute?(.showSteamDetail(viewState))
        }
    }

    private func libraryGameSummary(for identifier: LibraryGameIdentifier) -> LibraryGameSummary? {
        let libraryCollections = [
            state.recentlyPlayed,
            state.playingGames,
            state.ownedGames,
            state.backlogGames,
            state.playtimeRecommendations.map(\.game),
            state.friendRecommendations.map(\.game)
        ]

        for collection in libraryCollections {
            if let summary = collection.first(where: { $0.identifier == identifier }) {
                return summary
            }
        }

        return nil
    }

    private func startSteamLink() {
        apply(.clearError)
        print("[SteamLink] action=didTapSteamLink")

        Task {
            do {
                let authURL = try await startSteamLinkUseCase.execute()
                await MainActor.run {
                    self.apply(.clearError)
                    self.onRoute?(.showSteamLink(authURL))
                }
            } catch {
                let errorMessage = resolveSteamLinkErrorMessage(error)
                await MainActor.run {
                    self.apply(.setError(errorMessage))
                }
            }
        }
    }

    private func unlinkSteamAccount() {
        guard state.isSteamConnected else { return }
        guard !state.isUnlinkingSteamAccount else { return }

        apply(.clearError)
        apply(.clearSuccessMessage)
        apply(.setSteamOwnedSyncErrorCode(nil))
        apply(.setUnlinkingSteamAccount(true))
        print("[SteamLink] unlinkStarted")

        Task {
            do {
                let result = try await unlinkSteamAccountUseCase.execute()
                await MainActor.run {
                    let retainedPlayingGames = self.state.playingGames.filter { $0.gameSource != .steam }
                    let baseSections = self.state.sections.isEmpty ? self.makeLoadingSections() : self.state.sections

                    self.apply(.setUnlinkingSteamAccount(false))
                    self.libraryCacheStore.clear()
                    self.apply(
                        .setSteamState(
                            steamLinkStatus: result.steamLinkStatus,
                            isConnected: result.steamLinkStatus.isLinked,
                            syncStatus: .idle,
                            isSyncAvailable: false,
                            errorCode: nil
                        )
                    )
                    self.libraryCacheStore.clearSteamSyncDates()
                    self.apply(
                        .setLibraryItems(
                            recentlyPlayed: [],
                            playingGames: retainedPlayingGames,
                            ownedGames: [],
                            backlogGames: [],
                            likedGames: self.state.likedGames,
                            reviews: self.state.reviews
                        )
                    )
                    self.refreshSummaryState()
                    self.apply(.setPlaytimeRecommendations([]))
                    self.apply(
                        .setFriendRecommendations(
                            recommendations: [],
                            source: .none,
                            emptyState: .noFriendData
                        )
                    )
                    let disconnectedOverview = LibraryOverview(
                        steamLinkStatus: result.steamLinkStatus,
                        steamSyncStatus: .idle,
                        isSteamSyncAvailable: false,
                        steamSyncErrorCode: nil,
                        recentlyPlayed: [],
                        playing: retainedPlayingGames,
                        owned: [],
                        backlog: [],
                        playingSummary: state.serverSummaryByTab[.playing],
                        favoritesSummary: state.serverSummaryByTab[.favorites],
                        reviewedSummary: state.serverSummaryByTab[.reviewed]
                    )
                    let playingIdentifiers = Set(retainedPlayingGames.map(\.identifier))
                    let clearedSteamSections = [
                        self.makeRecentlyPlayedSection(
                            from: .success(disconnectedOverview),
                            playingIdentifiers: playingIdentifiers
                        ),
                        self.makePlayingSection(from: .success(disconnectedOverview)),
                        self.makeOwnedSection(from: .success(disconnectedOverview)),
                        self.makePlaytimeRecommendationsSection(from: .success([])),
                        self.makeFriendRecommendationsSection(
                            from: .success(
                                LibraryFriendRecommendationsResult(
                                    recommendations: [],
                                    source: .none,
                                    emptyState: .noFriendData
                                )
                            )
                        )
                    ].reduce(baseSections) { sections, section in
                        self.replacingSection(section, in: sections)
                    }
                    self.apply(.setSections(clearedSteamSections))
                    self.apply(.setSuccessMessage("Steam 연동이 해제되었어요"))
                    NotificationCenter.default.post(
                        name: .steamLinkStateDidChange,
                        object: nil,
                        userInfo: [SteamLinkStateChangeUserInfoKey.isLinked: result.steamLinkStatus.isLinked]
                    )
                    self.loadLibrary(trigger: .refresh)
                }
            } catch {
                let errorMessage = resolveSteamUnlinkErrorMessage(error)
                await MainActor.run {
                    self.apply(.setUnlinkingSteamAccount(false))
                    self.apply(.setError(errorMessage))
                }
            }
        }
    }

    private func showSteamPrivacyGuide(reason: String) {
        guard let settingsURL = SteamPrivacyGuideContent.settingsURL else {
            apply(.setError("Steam 설정 페이지를 열 수 없어요. 잠시 후 다시 시도해주세요."))
            return
        }

        print("[SteamPrivacyGuide] present reason=\(reason)")
        onRoute?(.showSteamPrivacyGuide(settingsURL))
    }

    private func syncOwnedSteamLibrary(trigger: SteamOwnedSyncTrigger) {
        guard !state.isSyncingOwnedSteamLibrary else { return }

        guard state.isSteamConnected else {
            if trigger != .silentAutomatic {
                apply(.clearError)
                apply(.setError("Steam 계정을 먼저 연결해주세요."))
            }
            return
        }

        if trigger.allowsDebounce,
           let lastSuccessfulSteamSyncDate = libraryCacheStore.loadLastSuccessfulSteamSyncDate(),
           Date().timeIntervalSince(lastSuccessfulSteamSyncDate) < SteamSyncPolicy.debounceInterval {
            print("[Library] syncOwnedSteamLibrary skipped reason=debounced trigger=\(trigger.logName)")
            apply(.setSuccessMessage("최근에 동기화를 완료했어요"))
            return
        }

        if trigger != .silentAutomatic {
            apply(.clearError)
            apply(.clearSuccessMessage)
        }
        apply(.setSteamOwnedSyncErrorCode(nil))
        apply(.setSyncingOwnedSteamLibrary(true))
        libraryCacheStore.saveLastAttemptedSteamSyncDate(Date())
        print("[Library] syncOwnedSteamLibrary started trigger=\(trigger.logName)")

        Task {
            do {
                let result = try await syncOwnedSteamLibraryUseCase.execute()
                await MainActor.run {
                    self.apply(.setSyncingOwnedSteamLibrary(false))

                    if self.isSteamOwnedLibraryUnavailable(errorCode: result.syncWarningCode) {
                        self.apply(.setSteamOwnedSyncErrorCode(result.syncWarningCode))
                        print(
                            "[SteamPrivacyGuide] " +
                            "present reason=owned_library_sync_unavailable " +
                            "errorCode=\(result.syncWarningCode ?? "nil")"
                        )
                        self.showSteamPrivacyGuide(reason: "owned_library_sync_unavailable")
                        self.loadLibrary(trigger: .refresh)
                        return
                    }

                    self.libraryCacheStore.saveLastSuccessfulSteamSyncDate(Date())
                    let lastSyncedAt = Date()
                    let refreshedSteamLinkStatus = SteamLinkStatus(
                        connectionState: self.state.steamLinkStatus.connectionState,
                        steamID: self.state.steamLinkStatus.steamID,
                        displayName: self.state.steamLinkStatus.displayName,
                        personaName: self.state.steamLinkStatus.personaName,
                        profileURL: self.state.steamLinkStatus.profileURL,
                        canSync: self.state.steamLinkStatus.canSync,
                        canDisconnect: self.state.steamLinkStatus.canDisconnect,
                        lastSteamSyncAt: lastSyncedAt
                    )
                    self.apply(
                        .setSteamState(
                            steamLinkStatus: refreshedSteamLinkStatus,
                            isConnected: self.state.isSteamConnected,
                            syncStatus: .success,
                            isSyncAvailable: self.state.isSteamSyncAvailable,
                            errorCode: nil
                        )
                    )
                    self.apply(.setSteamOwnedSyncErrorCode(nil))
                    if trigger.showsSuccessToast, !result.isRateLimitedIGDBEnrichmentPartialSuccess {
                        self.apply(.setSuccessMessage("보관함이 최신 상태로 업데이트됨"))
                    }
                    self.shouldForceOverviewReplacementAfterSteamSync = true
                    self.refreshLibraryAfterSteamSync()
                }
            } catch {
                await MainActor.run {
                    self.apply(.setSyncingOwnedSteamLibrary(false))
                    self.apply(.setSteamOwnedSyncErrorCode(resolveOwnedSyncInlineErrorCode(from: error)))
                    if trigger != .silentAutomatic {
                        self.apply(.setError(self.resolveSyncOwnedSteamLibraryErrorMessage(error)))
                    }
                }
            }
        }
    }

    private func refreshLibraryAfterSteamSync() {
        loadTask?.cancel()
        apply(.clearError)
        apply(.setRefreshing(true))
        apply(.setLoading(false))

        let selectedSort = state.selectedSort
        let requestedTab = state.selectedTab
        let previousSteamState = (
            steamLinkStatus: state.steamLinkStatus,
            isConnected: state.isSteamConnected,
            syncStatus: state.steamSyncStatus,
            isSyncAvailable: state.isSteamSyncAvailable,
            errorCode: state.steamSyncErrorCode
        )
        let hadVisibleSectionsBeforeLoad = state.sections.contains(where: { !isLoadingSection($0) })

        fetchSequence += 1
        let fetchID = fetchSequence
        print("[Library] postSyncRefresh started id=\(fetchID)")

        loadTask = Task { [weak self] in
            guard let self else { return }

            let overviewRawResult = await self.captureResult {
                try await self.fetchLibraryOverviewUseCase.execute(sort: selectedSort.userGameSort)
            }
            let overviewResult = await self.translatedOverview(from: overviewRawResult)

            await MainActor.run {
                guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "postSyncOverview") else { return }
                self.applyOverviewResult(
                    overviewResult,
                    trigger: .refresh,
                    previousSteamState: previousSteamState,
                    preserveCurrentSectionOnFailure: hadVisibleSectionsBeforeLoad
                )
            }

            let isSteamConnected = await MainActor.run { self.state.isSteamConnected }

            let playtimeResult: Result<[PlaytimeRecommendation], Error>
            if isSteamConnected {
                playtimeResult = await self.translatedPlaytimeRecommendations(
                    from: await self.captureResult {
                        try await self.fetchPlaytimeRecommendationsUseCase.execute()
                    }
                )
            } else {
                playtimeResult = .success([])
            }

            await MainActor.run {
                guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "postSyncPlaytimeRecommendations") else { return }
                self.applyPlaytimeRecommendationsResult(
                    playtimeResult,
                    trigger: .refresh,
                    preserveCurrentSectionOnFailure: true
                )
            }

            let friendRecommendationsResult = await self.translatedFriendRecommendations(
                from: await self.captureResult {
                    try await self.fetchLibraryFriendRecommendationsUseCase.execute(
                        isSteamConnected: isSteamConnected
                    )
                }
            )

            await MainActor.run {
                guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "postSyncFriendRecommendations") else { return }
                self.applyFriendRecommendationsResult(
                    friendRecommendationsResult,
                    trigger: .refresh,
                    preserveCurrentSectionOnFailure: true
                )
            }

            if isSteamConnected {
                let ownedCollectionResult = await self.translatedOwnedCollection(
                    from: await self.captureResult {
                        try await self.fetchOwnedLibraryUseCase.execute()
                    }
                )

                await MainActor.run {
                    guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "postSyncOwned") else { return }
                    self.applyOwnedCollectionRefreshResult(ownedCollectionResult)
                }

                let recentlyPlayedResult = await self.translatedRecentlyPlayedCollection(
                    from: await self.captureResult {
                        try await self.fetchRecentlyPlayedLibraryUseCase.execute()
                    }
                )

                await MainActor.run {
                    guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "postSyncRecentlyPlayed") else { return }
                    self.applyRecentlyPlayedRefreshResult(recentlyPlayedResult)
                }
            }

            await MainActor.run {
                guard self.shouldAcceptResponse(fetchID: fetchID, requestedTab: requestedTab, section: "postSyncFinalize") else { return }
                self.shouldForceOverviewReplacementAfterSteamSync = false
                self.apply(.setLoading(false))
                self.apply(.setRefreshing(false))
                self.apply(.clearAddingToPlaying)
                self.apply(.clearError)
                self.persistCurrentLibraryCache()
            }
        }
    }

    private func retrySteamPrivacyGuidance() {
        guard state.isSteamConnected else {
            loadLibrary(trigger: .refresh)
            return
        }

        print("[SteamPrivacyGuide] retryRequested")
        syncOwnedSteamLibrary(trigger: .retry)
    }

    private func addToPlaying(_ identifier: LibraryGameIdentifier) {
        guard !state.addingToPlayingIdentifiers.contains(identifier) else {
            print("[Library] addToPlaying skipped reason=requestInFlight identifier=\(identifier.uniqueKey)")
            return
        }

        guard let summary = state.recentlyPlayed.first(where: { $0.identifier == identifier }) else {
            print("[Library] addToPlaying invalidItem reason=missingSummary identifier=\(identifier.uniqueKey)")
            apply(.clearError)
            apply(.setError("게임 정보를 확인하지 못해 플레이 중 상태로 추가할 수 없어요."))
            return
        }

        guard let request = makeAddToPlayingRequest(from: summary) else {
            print(
                "[Library] addToPlaying invalidItem " +
                "identifier=\(summary.identifier.uniqueKey) " +
                "externalGameId=\(summary.identifier.sourceID) " +
                "title=\(summary.title)"
            )
            apply(.clearError)
            apply(.setError("게임 정보를 확인하지 못해 플레이 중 상태로 추가할 수 없어요."))
            return
        }

        apply(.clearError)
        apply(.setAddingToPlaying(identifier, isUpdating: true))
        print(
            "[Library] addToPlaying prepared " +
            "externalGameId=\(request.externalGameId) " +
            "title=\(request.title) " +
            "gameSource=\(request.gameSource.rawValue.uppercased()) " +
            "status=\(request.status.rawValue)"
        )

        Task {
            do {
                _ = try await updateLibraryGameStatusUseCase.execute(request: request)
                await MainActor.run {
                    self.loadLibrary(trigger: .refresh)
                }
            } catch {
                let libraryError = LibraryError.from(error: error)
                await MainActor.run {
                    self.apply(.setAddingToPlaying(identifier, isUpdating: false))
                    self.apply(.setError(libraryError.errorDescription ?? "플레이 중 상태를 저장하지 못했습니다."))
                }
            }
        }
    }

    private func removeFavorite(_ identifier: LibraryGameIdentifier) {
        guard identifier.source == .igdb,
              let gameID = identifier.detailGameID,
              !state.isLoading else { return }

        Task {
            do {
                let result = try await removeFavoriteUseCase.execute(gameId: String(gameID))

                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .favoriteDidChange,
                        object: nil,
                        userInfo: [
                            FavoriteChangeUserInfoKey.gameId: result.gameId,
                            FavoriteChangeUserInfoKey.isFavorite: result.isFavorite,
                            FavoriteChangeUserInfoKey.action: FavoriteChangeAction.removed.rawValue
                        ]
                    )
                }
            } catch {
                let favoriteError = FavoriteError.from(error: error)
                await MainActor.run {
                    self.apply(.setError(favoriteError.errorDescription ?? "찜 상태를 변경하지 못했습니다."))
                }
            }
        }
    }

    private func observeLibraryChanges() {
        NotificationCenter.default.publisher(for: .favoriteDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("[Library] refreshTriggered source=favoriteDidChange")
                self?.loadLibrary(trigger: .refresh)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .reviewDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("[Library] refreshTriggered source=reviewDidChange")
                self?.loadLibrary(trigger: .refresh)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .steamLinkDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let result = notification.userInfo?[SteamLinkChangeUserInfoKey.result] as? SteamLinkCallbackResult else {
                    return
                }
                print("[Library] refreshTriggered source=steamLinkDidComplete")
                self.handleSteamLinkCallbackResult(result)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .steamLinkStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("[Library] refreshTriggered source=steamLinkStateDidChange")
                self?.loadLibrary(trigger: .refresh)
            }
            .store(in: &cancellables)
    }

    private func translatedOverview(
        from result: Result<LibraryOverview, Error>
    ) async -> Result<LibraryOverview, Error> {
        switch result {
        case .success(let overview):
            let translatedRecentlyPlayed = await translateLibraryGames(
                overview.recentlyPlayed,
                context: "Library.recentlyPlayed"
            )
            let translatedPlaying = await translateLibraryGames(
                overview.playing,
                context: "Library.playing"
            )
            return .success(
                LibraryOverview(
                    steamLinkStatus: overview.steamLinkStatus,
                    steamSyncStatus: overview.steamSyncStatus,
                    isSteamSyncAvailable: overview.isSteamSyncAvailable,
                    steamSyncErrorCode: overview.steamSyncErrorCode,
                    recentlyPlayed: translatedRecentlyPlayed,
                    playing: translatedPlaying,
                    owned: await translateLibraryGames(
                        overview.owned,
                        context: "Library.owned"
                    ),
                    backlog: await translateLibraryGames(
                        overview.backlog,
                        context: "Library.backlog"
                    ),
                    playingSummary: overview.playingSummary,
                    favoritesSummary: overview.favoritesSummary,
                    reviewedSummary: overview.reviewedSummary
                )
            )
        case .failure(let error):
            return .failure(error)
        }
    }

    private func translatedWishlist(
        from result: Result<[FavoriteGameEntry], Error>
    ) async -> Result<[FavoriteGameEntry], Error> {
        switch result {
        case .success(let wishlist):
            return .success(await translateFavoriteEntries(wishlist))
        case .failure(let error):
            return .failure(error)
        }
    }

    private func translatedOwnedCollection(
        from result: Result<OwnedLibraryCollection, Error>
    ) async -> Result<OwnedLibraryCollection, Error> {
        switch result {
        case .success(let collection):
            return .success(
                OwnedLibraryCollection(
                    owned: await translateLibraryGames(collection.owned, context: "Library.owned.full"),
                    backlog: await translateLibraryGames(collection.backlog, context: "Library.backlog.full")
                )
            )
        case .failure(let error):
            return .failure(error)
        }
    }

    private func translatedRecentlyPlayedCollection(
        from result: Result<[LibraryGameSummary], Error>
    ) async -> Result<[LibraryGameSummary], Error> {
        switch result {
        case .success(let summaries):
            return .success(await translateLibraryGames(summaries, context: "Library.recentlyPlayed.full"))
        case .failure(let error):
            return .failure(error)
        }
    }

    private func translatedFriendRecommendations(
        from result: Result<LibraryFriendRecommendationsResult, Error>
    ) async -> Result<LibraryFriendRecommendationsResult, Error> {
        switch result {
        case .success(let payload):
            let translatedGames = await translateLibraryGames(
                payload.recommendations.map(\.game),
                context: "Library.friendRecommendations"
            )
            let translatedGamesByKey = Dictionary(
                uniqueKeysWithValues: translatedGames.map { ($0.identifier.uniqueKey, $0) }
            )

            return .success(
                LibraryFriendRecommendationsResult(
                    recommendations: payload.recommendations.map { recommendation in
                        SteamFriendRecommendation(
                            game: translatedGamesByKey[recommendation.game.identifier.uniqueKey] ?? recommendation.game,
                            friendCount: recommendation.friendCount,
                            reason: recommendation.reason
                        )
                    },
                    source: payload.source,
                    emptyState: payload.emptyState
                )
            )
        case .failure(let error):
            return .failure(error)
        }
    }

    private func translatedPlaytimeRecommendations(
        from result: Result<[PlaytimeRecommendation], Error>
    ) async -> Result<[PlaytimeRecommendation], Error> {
        switch result {
        case .success(let recommendations):
            let translatedGames = await translateLibraryGames(
                recommendations.map(\.game),
                context: "Library.playtimeRecommendations"
            )
            let translatedGamesByKey = Dictionary(
                uniqueKeysWithValues: translatedGames.map { ($0.identifier.uniqueKey, $0) }
            )

            return .success(
                recommendations.map { recommendation in
                    PlaytimeRecommendation(
                        game: translatedGamesByKey[recommendation.game.identifier.uniqueKey] ?? recommendation.game,
                        reason: recommendation.reason
                    )
                }
            )
        case .failure(let error):
            return .failure(error)
        }
    }

    private func translatedReviewed(
        from result: Result<[ReviewedGame], Error>
    ) async -> Result<[ReviewedGame], Error> {
        switch result {
        case .success(let reviewedGames):
            return .success(await translateReviewedGames(reviewedGames))
        case .failure(let error):
            return .failure(error)
        }
    }

    private func makeSections(
        overviewResult: Result<LibraryOverview, Error>,
        playtimeRecommendationsResult: Result<[PlaytimeRecommendation], Error>,
        friendRecommendationsResult: Result<LibraryFriendRecommendationsResult, Error>,
        wishlistResult: Result<[FavoriteGameEntry], Error>,
        reviewedResult: Result<[ReviewedGame], Error>
    ) -> [LibrarySectionViewState] {
        let playingIdentifiers = playingIdentifierSet(from: overviewResult)

        return [
            makeRecentlyPlayedSection(from: overviewResult, playingIdentifiers: playingIdentifiers),
            makePlaytimeRecommendationsSection(from: playtimeRecommendationsResult),
            makeReviewedSection(from: reviewedResult),
            makePlayingSection(from: overviewResult),
            makeOwnedSection(from: overviewResult),
            makeFriendRecommendationsSection(from: friendRecommendationsResult),
            makeWishlistSection(from: wishlistResult)
        ]
    }

    private func makeSectionListRoute(for kind: LibrarySectionKind) -> LibrarySectionListRoute? {
        switch kind {
        case .recentlyPlayed:
            guard !state.recentlyPlayed.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .recentlyPlayed,
                layoutStyle: .recentCards,
                items: sectionItems(for: .recentlyPlayed),
                loadBehavior: .recentlyPlayed
            )

        case .playing:
            guard !state.playingGames.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .playing,
                layoutStyle: .list,
                items: sectionItems(for: .playing),
                loadBehavior: .playing
            )

        case .owned:
            guard !state.ownedGames.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .owned,
                layoutStyle: .list,
                items: sectionItems(for: .owned),
                loadBehavior: .ownedGames(sort: state.selectedSort.userGameSort)
            )

        case .wishlist:
            guard !state.likedGames.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .wishlist,
                layoutStyle: .list,
                items: sectionItems(for: .wishlist),
                loadBehavior: .wishlist(sort: state.selectedSort.favoriteSort)
            )

        case .reviewed:
            guard !state.reviews.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .reviewed,
                layoutStyle: .list,
                items: sectionItems(for: .reviewed),
                loadBehavior: .reviewed(sort: state.selectedSort.reviewSort)
            )

        case .friendRecommendations:
            guard !state.friendRecommendations.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .friendRecommendations,
                layoutStyle: .list,
                items: sectionItems(for: .friendRecommendations),
                loadBehavior: .friendRecommendations
            )

        case .playtimeRecommendations:
            guard !state.playtimeRecommendations.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .playtimeRecommendations,
                layoutStyle: .list,
                items: sectionItems(for: .playtimeRecommendations),
                loadBehavior: .playtimeRecommendations
            )
        }
    }

    private func sectionItems(for kind: LibrarySectionKind) -> [LibraryCollectionItem] {
        state.sections.first(where: { $0.kind == kind })?.items ?? []
    }

    private func routeToRecentlyPlayedList() {
        routeToSectionListIfPossible(kind: .recentlyPlayed)
    }

    private func routeToPlayingGamesList() {
        routeToSectionListIfPossible(kind: .playing)
    }

    private func routeToOwnedGamesList() {
        routeToSectionListIfPossible(kind: .owned)
    }

    private func routeToLikedGamesList() {
        routeToSectionListIfPossible(kind: .wishlist)
    }

    private func routeToWrittenReviewsList() {
        routeToSectionListIfPossible(kind: .reviewed)
    }

    private func routeToFriendRecommendationsList() {
        routeToSectionListIfPossible(kind: .friendRecommendations)
    }

    private func routeToPlaytimeRecommendationsList() {
        routeToSectionListIfPossible(kind: .playtimeRecommendations)
    }

    private func routeToSectionListIfPossible(kind: LibrarySectionKind) {
        guard let route = makeSectionListRoute(for: kind) else { return }
        onRoute?(.showSectionList(route))
    }

    private func makeRecentlyPlayedItems(
        summaries: [LibraryGameSummary],
        playingIdentifiers: Set<LibraryGameIdentifier>,
        limit: Int?,
        showsAddToPlayingAction: Bool
    ) -> [LibraryCollectionItem] {
        let limitedSummaries = limitedLibrarySummaries(summaries, limit: limit)

        return limitedSummaries.map { summary in
            logRatingMapping(summary: summary, context: "Library.preview.recentCard")
            let isAddingToPlaying = state.addingToPlayingIdentifiers.contains(summary.identifier)
            let actionTitle: String?
            if showsAddToPlayingAction, !playingIdentifiers.contains(summary.identifier) {
                actionTitle = isAddingToPlaying ? "추가 중..." : "플레이 중으로 추가"
            } else {
                actionTitle = nil
            }

            return LibraryCollectionItem.recentCard(
                LibraryRecentGameCardViewState(
                    identifier: summary.identifier,
                    detailDestination: detailDestination(for: summary),
                    title: summary.displayTitle,
                    metadataText: recentlyPlayedMetadataText(for: summary),
                    ratingText: summary.formattedRatingText,
                    coverImageURL: summary.coverImageURL,
                    fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                    badgeText: "",
                    actionTitle: actionTitle,
                    isActionEnabled: showsAddToPlayingAction ? !isAddingToPlaying : true
                )
            )
        }
    }

    private func makeLibraryRowItems(
        summaries: [LibraryGameSummary],
        limit: Int?
    ) -> [LibraryCollectionItem] {
        let limitedSummaries = limitedLibrarySummaries(summaries, limit: limit)

        return limitedSummaries.map { summary in
            logRatingMapping(summary: summary, context: "Library.preview.row")
            let subtitleText = librarySubtitleText(for: summary)
            return LibraryCollectionItem.row(
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
    }

    private func limitedLibrarySummaries(
        _ summaries: [LibraryGameSummary],
        limit: Int?
    ) -> [LibraryGameSummary] {
        guard let limit else { return summaries }
        return Array(summaries.prefix(limit))
    }

    private func logRatingMapping(summary: LibraryGameSummary, context: String) {
        print(
            "[LibraryRatingMapping] " +
            "context=\(context) " +
            "title=\(summary.displayTitle) " +
            "igdbGameId=\(summary.igdbGameId.map(String.init) ?? "nil") " +
            "aggregatedRating=nil totalRating=nil " +
            "final ratingText=\(summary.formattedRatingText ?? "nil")"
        )
    }

    private func recentlyPlayedMetadataText(for summary: LibraryGameSummary) -> String {
        let display = RecentPlayMetadataFormatter.makeDisplay(
            lastPlayedAt: summary.lastPlayedAt,
            hasReliableLastPlayedAt: summary.hasReliableLastPlayedAt,
            recentPlaytimeMinutes: summary.recentPlaytimeMinutes,
            fallbackReason: summary.recentPlayFallbackReason
        )
        let recentPlayMetadataText = display.finalText
        let timestampUsedForRelativeText = display.relativeTimeText == nil
            ? "nil"
            : (summary.lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil")
        print(
            "[RecentPlayDisplay] " +
            "screen=Library.preview " +
            "title=\(summary.displayTitle) " +
            "lastPlayedAt=\(summary.lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil") " +
            "recentPlaytimeMinutes=\(summary.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
            "hasReliableLastPlayedAt=\(summary.hasReliableLastPlayedAt) " +
            "timestampUsedForRelativeText=\(timestampUsedForRelativeText) " +
            "relativeTime=\(display.relativeTimeText ?? "nil") " +
            "fallbackReason=\(summary.recentPlayFallbackReason ?? "nil") " +
            "finalText=\(recentPlayMetadataText)"
        )
        return recentPlayMetadataText

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
            if let genreText = displayableGenreText(for: summary) {
                return "Steam · \(genreText)"
            }

            return "Steam"
        }

        let components = [
            displayableGenreText(for: summary),
            knownReleaseText(for: summary)
        ].compactMap { $0 }

        guard !components.isEmpty else { return nil }
        return components.joined(separator: " · ")
    }

    private func displayableGenreText(for summary: LibraryGameSummary) -> String? {
        summary.displayableGenreText
    }

    private func normalizedPlatformText(for summary: LibraryGameSummary) -> String? {
        guard let platformText = sanitized(summary.platform),
              platformText != "—" else {
            return nil
        }

        return platformText
    }

    private func knownReleaseText(for summary: LibraryGameSummary) -> String? {
        guard summary.releaseYear > 0 else { return nil }
        return "\(summary.releaseYear)"
    }

    private func steamLibraryFallbackText(for summary: LibraryGameSummary) -> String {
        guard summary.identifier.source == .steam else {
            return "정보 보강 중"
        }

        return summary.shouldOpenFullGamePediaDetail ? "Steam" : "Steam · 정보 보강 중"
    }

    private func steamMetadataText(for summary: LibraryGameSummary) -> String {
        if let genreText = displayableGenreText(for: summary) {
            return "Steam · \(genreText)"
        }

        return steamLibraryFallbackText(for: summary)
    }

    private func detailDestination(for summary: LibraryGameSummary) -> LibraryGameDetailDestination? {
        if summary.shouldOpenFullGamePediaDetail,
           let igdbGameId = summary.igdbGameId,
           igdbGameId > 0 {
            print(
                "[DetailRouteMapping] " +
                "screen=Library.viewModel " +
                "title=\(summary.displayTitle) " +
                "externalGameId=\(summary.externalGameId) " +
                "igdbGameId=\(summary.igdbGameId.map(String.init) ?? "nil") " +
                "detailAvailable=\(summary.detailAvailable) " +
                "createdDestination=igdb:\(igdbGameId) " +
                "blockedReason=nil"
            )
            return .igdb(igdbGameId)
        }

        guard summary.shouldOpenSteamFallbackDetail else {
            print(
                "[DetailRouteMapping] " +
                "screen=Library.viewModel " +
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
            "screen=Library.viewModel " +
            "title=\(summary.displayTitle) " +
            "externalGameId=\(summary.externalGameId) " +
            "igdbGameId=\(summary.igdbGameId.map(String.init) ?? "nil") " +
            "detailAvailable=\(summary.detailAvailable) " +
            "createdDestination=steamFallback " +
            "blockedReason=nil"
        )
        return .steamFallback(makeSteamFallbackDetailViewState(from: summary))
    }

    private func makeSteamFallbackDetailViewState(
        from summary: LibraryGameSummary
    ) -> SteamFallbackGameDetailViewState {
        let recentPlayDisplay = RecentPlayMetadataFormatter.makeDisplay(
            lastPlayedAt: summary.lastPlayedAt,
            hasReliableLastPlayedAt: summary.hasReliableLastPlayedAt,
            recentPlaytimeMinutes: summary.recentPlaytimeMinutes,
            fallbackReason: summary.recentPlayFallbackReason
        )
        let playtimeValueText: String? = {
            if summary.hasReliableLastPlayedAt || (summary.recentPlaytimeMinutes ?? 0) > 0 {
                return recentPlayDisplay.finalText
            }
            return SteamPlaytimeFormatter.expandedPlaytimeValue(
                minutes: summary.playtimeMinutes ?? summary.recentPlaytimeMinutes
            )
        }()
        let timestampUsedForRelativeText = recentPlayDisplay.relativeTimeText == nil
            ? "nil"
            : (summary.lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil")
        print(
            "[RecentPlayDisplay] " +
            "screen=GameDetail.steamFallback " +
            "title=\(summary.displayTitle) " +
            "lastPlayedAt=\(summary.lastPlayedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil") " +
            "recentPlaytimeMinutes=\(summary.recentPlaytimeMinutes.map(String.init) ?? "nil") " +
            "hasReliableLastPlayedAt=\(summary.hasReliableLastPlayedAt) " +
            "timestampUsedForRelativeText=\(timestampUsedForRelativeText) " +
            "relativeTime=\(recentPlayDisplay.relativeTimeText ?? "nil") " +
            "finalText=\(playtimeValueText ?? "nil")"
        )
        return SteamFallbackGameDetailViewState(
            title: summary.displayTitle,
            coverImageURL: summary.coverImageURL,
            fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
            sourceLabelText: "Steam",
            metadataText: steamMetadataText(for: summary),
            descriptionText: "Steam에서 가져온 게임입니다.",
            playtimeValueText: playtimeValueText,
            externalGameId: summary.externalGameId,
            gameSource: summary.gameSource,
            metadataEnriched: summary.metadataEnriched,
            matchStatus: summary.matchStatus,
            enrichmentStatus: summary.enrichmentStatus
        )
    }

    private func playingIdentifierSet(from result: Result<LibraryOverview, Error>) -> Set<LibraryGameIdentifier> {
        guard case .success(let overview) = result else { return [] }
        return Set(overview.playing.map(\.identifier))
    }

    private func makeRecentlyPlayedSection(
        from result: Result<LibraryOverview, Error>,
        playingIdentifiers: Set<LibraryGameIdentifier>
    ) -> LibrarySectionViewState {
        switch result {
        case .success(let overview):
            let displaySummaries = resolvedRecentlyPlayedDisplaySummaries(from: overview)
            let hasNonBlockingMetadataIssue = isNonBlockingSteamMetadataIssue(
                errorCode: overview.steamSyncErrorCode
            )

            if !overview.steamLinkStatus.isLinked {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.connect",
                                style: .banner,
                                title: "최근 플레이 기록이 없어요",
                                message: "Steam 계정을 연동하면\n최근 플레이한 게임을 자동으로 가져올 수 있어요.",
                                detailText: nil,
                                buttonTitle: "Steam 연동하기",
                                action: .connectSteam
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if isSteamTokenExpired(
                syncStatus: overview.steamSyncStatus,
                errorCode: overview.steamSyncErrorCode
            ) {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.tokenExpired",
                                style: .error,
                                title: "Steam 연결이 만료되었어요",
                                message: "다시 연동하면 Steam 게임 정보를 계속 가져올 수 있어요.",
                                detailText: nil,
                                buttonTitle: "다시 연동하기",
                                action: .connectSteam
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if isSteamRecentlyPlayedUnavailable(
                syncStatus: overview.steamSyncStatus,
                errorCode: overview.steamSyncErrorCode
            ) {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.privacyUnavailable",
                                style: .error,
                                title: "최근 플레이 정보를 가져올 수 없어요",
                                message: "Steam 프로필 공개 설정을 확인해 주세요.",
                                detailText: nil,
                                buttonTitle: "설정 방법 보기",
                                action: .showSteamPrivacyGuide
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if (overview.steamSyncStatus == .idle || isSteamSyncInProgress(syncStatus: overview.steamSyncStatus)),
               displaySummaries.isEmpty,
               state.recentlyPlayedSource == .none {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.loading",
                                style: .loading,
                                title: "최근 플레이 정보를 불러오는 중...",
                                message: "Steam 데이터를 가져오는 중이에요.",
                                detailText: nil,
                                buttonTitle: nil,
                                action: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if isSteamSyncFailed(
                syncStatus: overview.steamSyncStatus,
                isSyncAvailable: overview.isSteamSyncAvailable,
                errorCode: overview.steamSyncErrorCode
            ) {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.unavailable",
                                style: .error,
                                title: "최근 플레이 정보를 불러오지 못했어요",
                                message: "잠시 후 다시 시도해 주세요.",
                                detailText: nil,
                                buttonTitle: "다시 시도",
                                action: .retrySteamSync
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if displaySummaries.isEmpty {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.empty",
                                style: .empty,
                                title: "최근 플레이한 Steam 게임이 아직 없어요",
                                message: "최근 2주 내 플레이한 Steam 게임이 있으면 여기에 표시돼요.",
                                detailText: nil,
                                buttonTitle: hasNonBlockingMetadataIssue ? nil : "라이브러리 새로고침",
                                action: hasNonBlockingMetadataIssue ? nil : .retrySteamSync
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            return LibrarySectionViewState(
                kind: .recentlyPlayed,
                layoutStyle: .recentCards,
                items: makeRecentlyPlayedItems(
                    summaries: displaySummaries,
                    playingIdentifiers: playingIdentifiers,
                    limit: PreviewLimit.recentCards,
                    showsAddToPlayingAction: false
                ),
                showsSeeAll: displaySummaries.count >= PreviewLimit.recentCards
            )

        case .failure:
            return LibrarySectionViewState(
                kind: .recentlyPlayed,
                layoutStyle: .message,
                items: [
                    .message(
                        LibraryMessageViewState(
                            id: "recentlyPlayed.error",
                            style: .error,
                            title: nil,
                            message: "최근 플레이 정보를 불러오지 못했어요.",
                            detailText: nil,
                            buttonTitle: nil,
                            action: nil
                        )
                    )
                ],
                showsSeeAll: false
            )
        }
    }

    private func resolvedRecentlyPlayedDisplaySummaries(from overview: LibraryOverview) -> [LibraryGameSummary] {
        if !overview.recentlyPlayed.isEmpty {
            return overview.recentlyPlayed
        }

        if state.recentlyPlayedSource == .snapshot,
           !state.recentlyPlayed.isEmpty {
            return state.recentlyPlayed
        }

        return overview.recentlyPlayed
    }

    private func makePlayingSection(from result: Result<LibraryOverview, Error>) -> LibrarySectionViewState {
        switch result {
        case .success(let overview):
            if overview.playing.isEmpty {
                return LibrarySectionViewState(
                    kind: .playing,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "playing.empty",
                                style: .empty,
                                title: nil,
                                message: "플레이 중인 게임이 아직 없어요.",
                                detailText: nil,
                                buttonTitle: nil,
                                action: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            return LibrarySectionViewState(
                kind: .playing,
                layoutStyle: .list,
                items: makeLibraryRowItems(
                    summaries: overview.playing,
                    limit: PreviewLimit.listRows
                ),
                showsSeeAll: overview.playing.count >= PreviewLimit.listRows
            )

        case .failure:
            return LibrarySectionViewState(
                kind: .playing,
                layoutStyle: .message,
                items: [
                    .message(
                        LibraryMessageViewState(
                            id: "playing.error",
                            style: .error,
                            title: nil,
                            message: "플레이 중 목록을 불러오지 못했어요.",
                            detailText: nil,
                            buttonTitle: nil,
                            action: nil
                        )
                    )
                ],
                showsSeeAll: false
            )
        }
    }

    private func makeWishlistSection(from result: Result<[FavoriteGameEntry], Error>) -> LibrarySectionViewState {
        switch result {
        case .success(let wishlist):
            if wishlist.isEmpty {
                return LibrarySectionViewState(
                    kind: .wishlist,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "wishlist.empty",
                                style: .empty,
                                title: nil,
                                message: "찜한 게임이 아직 없어요.",
                                detailText: nil,
                                buttonTitle: nil,
                                action: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            let items = wishlist.prefix(PreviewLimit.listRows).map { entry in
                LibraryCollectionItem.row(
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
                        ratingText: entry.game.rating > 0 ? String(format: "%.1f", entry.game.rating) : nil,
                        trailingAction: .removeWishlist
                    )
                )
            }

            return LibrarySectionViewState(
                kind: .wishlist,
                layoutStyle: .list,
                items: items,
                showsSeeAll: wishlist.count > PreviewLimit.listRows
            )

        case .failure:
            return LibrarySectionViewState(
                kind: .wishlist,
                layoutStyle: .message,
                items: [
                    .message(
                        LibraryMessageViewState(
                            id: "wishlist.error",
                            style: .error,
                            title: nil,
                            message: "찜한 게임을 불러오지 못했어요.",
                            detailText: nil,
                            buttonTitle: nil,
                            action: nil
                        )
                    )
                ],
                showsSeeAll: false
            )
        }
    }

    private func makeOwnedSection(from result: Result<LibraryOverview, Error>) -> LibrarySectionViewState {
        switch result {
        case .success(let overview):
            let hasNonBlockingMetadataIssue = isNonBlockingSteamMetadataIssue(
                errorCode: state.steamOwnedSyncErrorCode ?? overview.steamSyncErrorCode
            )
            if !overview.steamLinkStatus.isLinked {
                return LibrarySectionViewState(
                    kind: .owned,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "owned.connect",
                                style: .banner,
                                title: "보유 게임이 없어요",
                                message: "Steam 보관함을 연결하면\n보유 중인 게임 목록을 자동으로 불러올 수 있어요.",
                                detailText: nil,
                                buttonTitle: "Steam 보관함 가져오기",
                                action: .connectSteam
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if isSteamTokenExpired(
                syncStatus: overview.steamSyncStatus,
                errorCode: state.steamOwnedSyncErrorCode ?? overview.steamSyncErrorCode
            ) && overview.owned.isEmpty {
                return LibrarySectionViewState(
                    kind: .owned,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "owned.tokenExpired",
                                style: .error,
                                title: "Steam 연결이 만료되었어요",
                                message: "다시 연동하면 Steam 게임 정보를 계속 가져올 수 있어요.",
                                detailText: nil,
                                buttonTitle: "다시 연동하기",
                                action: .connectSteam
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if (state.isSyncingOwnedSteamLibrary || isSteamSyncInProgress(syncStatus: overview.steamSyncStatus)),
               overview.owned.isEmpty {
                return LibrarySectionViewState(
                    kind: .owned,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "owned.loading",
                                style: .loading,
                                title: nil,
                                message: "보유 게임 목록을 가져오는 중...",
                                detailText: nil,
                                buttonTitle: nil,
                                action: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if (isSteamOwnedLibraryPrivacyUnavailable(errorCode: state.steamOwnedSyncErrorCode)
                || overview.steamSyncStatus == .privateProfile),
               overview.owned.isEmpty {
                return LibrarySectionViewState(
                    kind: .owned,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "owned.privacyUnavailable",
                                style: .error,
                                title: "Steam 프로필이 비공개 상태예요",
                                message: "Steam 프로필 및 게임 보관함이 공개 상태여야\n보유 게임 정보를 가져올 수 있어요.",
                                detailText: "Steam 설정 → 개인정보 설정\n→ 게임 상세 정보 공개 로 변경해 주세요.",
                                buttonTitle: "설정 방법 보기",
                                action: .showSteamPrivacyGuide
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if (isSteamOwnedLibrarySyncFailed(errorCode: state.steamOwnedSyncErrorCode)
                || isSteamSyncFailed(
                    syncStatus: overview.steamSyncStatus,
                    isSyncAvailable: overview.isSteamSyncAvailable,
                    errorCode: overview.steamSyncErrorCode
                )),
               overview.owned.isEmpty {
                return LibrarySectionViewState(
                    kind: .owned,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "owned.syncFailed",
                                style: .error,
                                title: "Steam 데이터를 불러오지 못했어요",
                                message: "잠시 후 다시 시도해 주세요.",
                                detailText: nil,
                                buttonTitle: "다시 시도",
                                action: .retryOwnedSteamSync
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if overview.owned.isEmpty {
                print("[LibraryOwnedPreview] sourceCount=0 renderedCount=0 state=empty")
                return LibrarySectionViewState(
                    kind: .owned,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "owned.empty",
                                style: .empty,
                                title: "가져온 보유 게임이 아직 없어요",
                                message: "Steam 보관함을 다시 동기화해 보세요.",
                                detailText: nil,
                                buttonTitle: hasNonBlockingMetadataIssue ? nil : "다시 동기화",
                                action: hasNonBlockingMetadataIssue ? nil : .retryOwnedSteamSync
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            let previewItems = makeLibraryRowItems(
                summaries: overview.owned,
                limit: PreviewLimit.listRows
            )
            print(
                "[LibraryOwnedPreview] " +
                "sourceCount=\(overview.owned.count) " +
                "renderedCount=\(previewItems.count)"
            )
            return LibrarySectionViewState(
                kind: .owned,
                layoutStyle: .list,
                items: previewItems,
                showsSeeAll: overview.owned.count >= PreviewLimit.listRows
            )

        case .failure:
            return LibrarySectionViewState(
                kind: .owned,
                layoutStyle: .message,
                items: [
                    .message(
                        LibraryMessageViewState(
                            id: "owned.error",
                            style: .error,
                            title: nil,
                            message: "보유 게임을 불러오지 못했어요.",
                            detailText: nil,
                            buttonTitle: nil,
                            action: nil
                        )
                    )
                ],
                showsSeeAll: false
            )
        }
    }

    private func makePlaytimeRecommendationsSection(
        from result: Result<[PlaytimeRecommendation], Error>
    ) -> LibrarySectionViewState {
        switch result {
        case .success(let recommendations):
            guard !recommendations.isEmpty else {
                return LibrarySectionViewState(
                    kind: .playtimeRecommendations,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "playtimeRecommendations.empty",
                                style: .empty,
                                title: nil,
                                message: "추천할 게임이 아직 없어요",
                                detailText: nil,
                                buttonTitle: nil,
                                action: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            let items = recommendations.prefix(PreviewLimit.recommendationRows).map(makePlaytimeRecommendationCardItem)
            return LibrarySectionViewState(
                kind: .playtimeRecommendations,
                layoutStyle: .recentCards,
                items: items,
                showsSeeAll: recommendations.count > PreviewLimit.recommendationRows
            )

        case .failure:
            return LibrarySectionViewState(
                kind: .playtimeRecommendations,
                layoutStyle: .message,
                items: [
                    .message(
                        LibraryMessageViewState(
                            id: "playtimeRecommendations.error",
                            style: .error,
                            title: nil,
                            message: "추천 정보를 불러오지 못했어요",
                            detailText: nil,
                            buttonTitle: nil,
                            action: nil
                        )
                    )
                ],
                showsSeeAll: false
            )
        }
    }

    private func makePlaytimeRecommendationRowItem(
        from recommendation: PlaytimeRecommendation
    ) -> LibraryCollectionItem {
        makePlaytimeRecommendationCardItem(from: recommendation)
    }

    private func makePlaytimeRecommendationCardItem(
        from recommendation: PlaytimeRecommendation
    ) -> LibraryCollectionItem {
        let summary = recommendation.game
        return .recentCard(
            LibraryRecentGameCardViewState(
                identifier: summary.identifier,
                detailDestination: detailDestination(for: summary),
                title: summary.displayTitle,
                metadataText: displayableGenreText(for: summary) ?? librarySubtitleText(for: summary),
                ratingText: summary.formattedRatingText,
                coverImageURL: summary.coverImageURL,
                fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                badgeText: "",
                actionTitle: nil,
                isActionEnabled: true
            )
        )
    }

    private func playtimeRecommendationSubtitleText(
        for recommendation: PlaytimeRecommendation
    ) -> String {
        guard let reason = sanitized(recommendation.reason) else {
            return "플레이 성향과 잘 맞는 게임이에요"
        }

        switch reason {
        case "자주 즐기는 장르와 잘 맞아요":
            return "자주 즐기는 장르에 가까워요"
        default:
            return reason
        }
    }

    private func makeFriendRecommendationsSection(
        from result: Result<LibraryFriendRecommendationsResult, Error>
    ) -> LibrarySectionViewState {
        switch result {
        case .success(let payload):
            guard !payload.recommendations.isEmpty else {
                return LibrarySectionViewState(
                    kind: .friendRecommendations,
                    layoutStyle: .message,
                    items: [
                        .message(friendRecommendationsEmptyMessageViewState(for: payload.emptyState))
                    ],
                    showsSeeAll: false
                )
            }

            let items = payload.recommendations.prefix(PreviewLimit.recommendationRows).map(makeFriendRecommendationRowItem)
            return LibrarySectionViewState(
                kind: .friendRecommendations,
                layoutStyle: .list,
                items: items,
                showsSeeAll: payload.recommendations.count > PreviewLimit.recommendationRows
            )

        case .failure:
            return LibrarySectionViewState(
                kind: .friendRecommendations,
                layoutStyle: .message,
                items: [
                    .message(
                        LibraryMessageViewState(
                            id: "friendRecommendations.error",
                            style: .error,
                            title: nil,
                            message: "친구 기반 추천을 불러오지 못했어요",
                            detailText: "잠시 후 다시 시도해 주세요.",
                            buttonTitle: "다시 시도",
                            action: .retryFriendRecommendations
                        )
                    )
                ],
                showsSeeAll: false
            )
        }
    }

    private func friendRecommendationsEmptyMessageViewState(
        for emptyState: LibraryFriendRecommendationsEmptyState?
    ) -> LibraryMessageViewState {
        let title: String?
        let message: String
        let detailText: String?

        switch emptyState ?? .noFriendData {
        case .noFriendData:
            title = "친구 추천을 불러올 수 없어요"
            if state.isSteamConnected {
                message = "아직 추천을 만들 친구 데이터가 없어요."
                detailText = "친구를 추가하거나 친구 활동이 쌓이면 추천을 보여드릴게요."
            } else {
                message = "아직 추천을 만들 친구 데이터가 없어요."
                detailText = "친구를 추가하거나 Steam 계정을 연동해보세요."
            }
        case .insufficientActivity:
            title = "아직 추천할 게임이 없어요"
            message = "친구의 찜, 리뷰, 라이브러리 활동이 더 쌓이면 추천을 보여드릴게요."
            detailText = nil
        case .steamUnavailable:
            title = "Steam 친구 데이터를 불러올 수 없어요"
            message = "Steam 친구 정보가 없거나 공개 설정에 따라 추천을 불러올 수 없어요."
            detailText = nil
        }

        return LibraryMessageViewState(
            id: "friendRecommendations.empty.\((emptyState ?? .noFriendData).rawValue)",
            style: .empty,
            title: title,
            message: message,
            detailText: detailText,
            buttonTitle: nil,
            action: nil
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

    private func friendRecommendationSubtitleText(
        for recommendation: SteamFriendRecommendation
    ) -> String {
        let friendCount = max(recommendation.friendCount, 0)
        if let reason = sanitized(recommendation.reason), reason.contains("플레이 중") {
            return friendCount > 0 ? "친구 \(friendCount)명이 플레이 중" : "친구들이 플레이 중인 게임"
        }

        if let reason = sanitized(recommendation.reason), reason.contains("보유") {
            return "친구들이 많이 보유한 게임"
        }

        return friendCount > 0 ? "친구 \(friendCount)명이 주목한 게임" : "친구들이 많이 보유한 게임"
    }

    private func makeReviewedSection(from result: Result<[ReviewedGame], Error>) -> LibrarySectionViewState {
        switch result {
        case .success(let reviewedGames):
            if reviewedGames.isEmpty {
                return LibrarySectionViewState(
                    kind: .reviewed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "reviewed.empty",
                                style: .empty,
                                title: nil,
                                message: "작성한 리뷰가 아직 없어요.",
                                detailText: nil,
                                buttonTitle: nil,
                                action: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            let items = reviewedGames.prefix(PreviewLimit.listRows).map { reviewedGame in
                LibraryCollectionItem.row(
                    LibraryGameRowViewState(
                        identifier: LibraryGameIdentifier(
                            source: .igdb,
                            sourceID: String(reviewedGame.gameId),
                            canonicalGameID: reviewedGame.gameId
                        ),
                        detailDestination: .igdb(reviewedGame.gameId),
                        title: reviewedGame.game.displayTitle,
                        subtitleText: "평가함",
                        metadataText: reviewedGame.game.genre,
                        coverImageURL: reviewedGame.game.coverImageURL,
                        ratingText: String(format: "%.1f", reviewedGame.rating),
                        trailingAction: nil
                    )
                )
            }

            return LibrarySectionViewState(
                kind: .reviewed,
                layoutStyle: .list,
                items: items,
                showsSeeAll: reviewedGames.count > PreviewLimit.listRows
            )

        case .failure:
            return LibrarySectionViewState(
                kind: .reviewed,
                layoutStyle: .message,
                items: [
                    .message(
                        LibraryMessageViewState(
                            id: "reviewed.error",
                            style: .error,
                            title: nil,
                            message: "작성한 리뷰를 불러오지 못했어요.",
                            detailText: nil,
                            buttonTitle: nil,
                            action: nil
                        )
                    )
                ],
                showsSeeAll: false
            )
        }
    }

    private func resolveErrorMessage(
        overviewResult: Result<LibraryOverview, Error>,
        playtimeRecommendationsResult: Result<[PlaytimeRecommendation], Error>,
        friendRecommendationsResult: Result<LibraryFriendRecommendationsResult, Error>,
        wishlistResult: Result<[FavoriteGameEntry], Error>,
        reviewedResult: Result<[ReviewedGame], Error>
    ) -> String? {
        _ = playtimeRecommendationsResult
        _ = friendRecommendationsResult
        let errors = [
            overviewResult.failure,
            wishlistResult.failure,
            reviewedResult.failure
        ].compactMap { $0 }

        guard !errors.isEmpty else { return nil }
        if errors.count > 1 {
            return "일부 라이브러리 정보를 불러오지 못했어요."
        }

        let error = errors[0]
        if overviewResult.failure != nil {
            return LibraryError.from(error: error).errorDescription
        }
        if wishlistResult.failure != nil {
            return FavoriteError.from(error: error).errorDescription
        }
        return ReviewError.from(error: error).errorDescription
    }

    private func translateLibraryGames(_ summaries: [LibraryGameSummary], context: String) async -> [LibraryGameSummary] {
        guard !summaries.isEmpty else { return [] }

        let translationItems = summaries.compactMap { summary -> TranslationRequestItem? in
            guard summary.translatedTitle == nil else { return nil }
            return TranslationRequestItem(
                identifier: summary.identifier.uniqueKey,
                field: "title",
                text: summary.title
            )
        }

        guard !translationItems.isEmpty else { return summaries }

        let translatedTitles = Dictionary(
            uniqueKeysWithValues: await translateTextUseCase.execute(
                items: translationItems,
                context: context,
                sourceLanguage: "en"
            ).map { ($0.identifier, $0.translatedText) }
        )

        return summaries.map { summary in
            summary.replacingTranslatedTitle(translatedTitles[summary.identifier.uniqueKey])
        }
    }

    private func translateFavoriteEntries(_ entries: [FavoriteGameEntry]) async -> [FavoriteGameEntry] {
        let translatedGames = await translateGames(entries.map(\.game), context: "Library.wishlist")
        let translatedGamesByID = Dictionary(uniqueKeysWithValues: translatedGames.map { ($0.id, $0) })

        return entries.map { entry in
            FavoriteGameEntry(
                favorite: entry.favorite,
                game: translatedGamesByID[entry.game.id] ?? entry.game
            )
        }
    }

    private func translateReviewedGames(_ reviewedGames: [ReviewedGame]) async -> [ReviewedGame] {
        let translatedGames = await translateGames(reviewedGames.map(\.game), context: "Library.reviewed")
        let translatedGamesByID = Dictionary(uniqueKeysWithValues: translatedGames.map { ($0.id, $0) })

        return reviewedGames.map { reviewedGame in
            ReviewedGame(
                reviewId: reviewedGame.reviewId,
                gameId: reviewedGame.gameId,
                rating: reviewedGame.rating,
                content: reviewedGame.content,
                createdAt: reviewedGame.createdAt,
                game: translatedGamesByID[reviewedGame.game.id] ?? reviewedGame.game
            )
        }
    }

    private func translateGames(_ games: [Game], context: String) async -> [Game] {
        guard !games.isEmpty else { return games }

        let titleItems = games.compactMap { game -> TranslationRequestItem? in
            guard game.translatedTitle == nil else { return nil }
            return TranslationRequestItem(
                identifier: String(game.id),
                field: "title",
                text: game.title
            )
        }

        guard !titleItems.isEmpty else { return games }

        let translatedTitles = Dictionary(
            uniqueKeysWithValues: await translateTextUseCase.execute(
                items: titleItems,
                context: "\(context).title",
                sourceLanguage: "en"
            ).map { ($0.identifier, $0.translatedText) }
        )

        return games.map { game in
            game.replacingTranslated(translatedTitle: translatedTitles[String(game.id)])
        }
    }

    private func releaseText(for summary: LibraryGameSummary) -> String {
        releaseText(for: summary.releaseYear)
    }

    private func releaseText(for year: Int) -> String {
        year > 0 ? "\(year)" : "출시 예정"
    }

    private func captureResult<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func logSectionResponseArrived<T>(
        id: Int,
        section: String,
        result: Result<T, Error>
    ) {
        switch result {
        case .success(let value):
            if let overview = value as? LibraryOverview {
                print(
                    "[Library] responseArrived id=\(id) section=\(section) " +
                    "recentlyPlayedCount=\(overview.recentlyPlayed.count) " +
                    "playingCount=\(overview.playing.count) " +
                    "ownedCount=\(overview.owned.count) " +
                    "backlogCount=\(overview.backlog.count) " +
                    "isSteamConnected=\(overview.steamLinkStatus.isLinked) " +
                    "steamSyncStatus=\(overview.steamSyncStatus.rawValue) " +
                    "isSteamSyncAvailable=\(overview.isSteamSyncAvailable)"
                )
                return
            }

            if let wishlist = value as? [FavoriteGameEntry] {
                print("[Library] responseArrived id=\(id) section=\(section) likedCount=\(wishlist.count)")
                return
            }

            if let recommendations = value as? LibraryFriendRecommendationsResult {
                print(
                    "[Library] responseArrived id=\(id) section=\(section) " +
                    "friendRecommendationsCount=\(recommendations.recommendations.count) " +
                    "friendRecommendationsSource=\(recommendations.source.rawValue) " +
                    "friendRecommendationsEmptyState=\(recommendations.emptyState?.rawValue ?? "nil")"
                )
                return
            }

            if let recommendations = value as? [PlaytimeRecommendation] {
                print(
                    "[Library] responseArrived id=\(id) section=\(section) " +
                    "playtimeRecommendationsCount=\(recommendations.count)"
                )
                return
            }

            if let reviewedGames = value as? [ReviewedGame] {
                print("[Library] responseArrived id=\(id) section=\(section) reviewsCount=\(reviewedGames.count)")
                return
            }

            print("[Library] responseArrived id=\(id) section=\(section)")

        case .failure(let error):
            print(
                "[Library] responseArrived id=\(id) section=\(section) " +
                "error=\(error.localizedDescription)"
            )
        }
    }

    private func logResponseSummary(
        id: Int,
        overviewResult: Result<LibraryOverview, Error>,
        playtimeRecommendationsResult: Result<[PlaytimeRecommendation], Error>,
        friendRecommendationsResult: Result<LibraryFriendRecommendationsResult, Error>,
        wishlistResult: Result<[FavoriteGameEntry], Error>,
        reviewedResult: Result<[ReviewedGame], Error>
    ) {
        let overviewSummary: String
        switch overviewResult {
        case .success(let overview):
            overviewSummary =
                "recentlyPlayedCount=\(overview.recentlyPlayed.count) " +
                "playingCount=\(overview.playing.count) " +
                "ownedCount=\(overview.owned.count) " +
                "backlogCount=\(overview.backlog.count) " +
                "isSteamConnected=\(overview.steamLinkStatus.isLinked) " +
                "steamSyncStatus=\(overview.steamSyncStatus.rawValue) " +
                "isSteamSyncAvailable=\(overview.isSteamSyncAvailable)"
        case .failure(let error):
            overviewSummary = "overviewError=\(LibraryError.from(error: error).errorDescription ?? error.localizedDescription)"
        }

        let wishlistSummary: String
        switch wishlistResult {
        case .success(let wishlist):
            wishlistSummary = "likedCount=\(wishlist.count)"
        case .failure(let error):
            wishlistSummary = "likedError=\(FavoriteError.from(error: error).errorDescription ?? error.localizedDescription)"
        }

        let reviewedSummary: String
        switch reviewedResult {
        case .success(let reviewedGames):
            reviewedSummary = "reviewsCount=\(reviewedGames.count)"
        case .failure(let error):
            reviewedSummary = "reviewsError=\(ReviewError.from(error: error).errorDescription ?? error.localizedDescription)"
        }

        let friendRecommendationsSummary: String
        switch friendRecommendationsResult {
        case .success(let recommendations):
            friendRecommendationsSummary =
                "friendRecommendationsCount=\(recommendations.recommendations.count) " +
                "friendRecommendationsSource=\(recommendations.source.rawValue) " +
                "friendRecommendationsEmptyState=\(recommendations.emptyState?.rawValue ?? "nil")"
        case .failure(let error):
            friendRecommendationsSummary = "friendRecommendationsError=\(LibraryError.from(error: error).errorDescription ?? error.localizedDescription)"
        }

        let playtimeRecommendationsSummary: String
        switch playtimeRecommendationsResult {
        case .success(let recommendations):
            playtimeRecommendationsSummary = "playtimeRecommendationsCount=\(recommendations.count)"
        case .failure(let error):
            playtimeRecommendationsSummary = "playtimeRecommendationsError=\(LibraryError.from(error: error).errorDescription ?? error.localizedDescription)"
        }

        print(
            "[Library] responseArrived id=\(id) " +
            "\(overviewSummary) " +
            "\(playtimeRecommendationsSummary) " +
            "\(friendRecommendationsSummary) " +
            "\(wishlistSummary) " +
            "\(reviewedSummary)"
        )
    }

    private func logMappedState(
        id: Int,
        libraryItems: (
            recentlyPlayed: [LibraryGameSummary],
            playingGames: [LibraryGameSummary],
            ownedGames: [LibraryGameSummary],
            backlogGames: [LibraryGameSummary],
            playtimeRecommendations: [PlaytimeRecommendation],
            friendRecommendations: [SteamFriendRecommendation],
            friendRecommendationsSource: LibraryFriendRecommendationSource,
            friendRecommendationsEmptyState: LibraryFriendRecommendationsEmptyState?,
            likedGames: [Game],
            reviews: [ReviewedGame]
        ),
        steamState: (isConnected: Bool, syncStatus: SteamSyncStatus, isSyncAvailable: Bool, errorCode: String?)
    ) {
        print(
            "[Library] mappedState id=\(id) " +
            "recentlyPlayedCount=\(libraryItems.recentlyPlayed.count) " +
            "playingGamesCount=\(libraryItems.playingGames.count) " +
            "ownedGamesCount=\(libraryItems.ownedGames.count) " +
            "backlogGamesCount=\(libraryItems.backlogGames.count) " +
            "playtimeRecommendationsCount=\(libraryItems.playtimeRecommendations.count) " +
            "friendRecommendationsCount=\(libraryItems.friendRecommendations.count) " +
            "friendRecommendationsSource=\(libraryItems.friendRecommendationsSource.rawValue) " +
            "friendRecommendationsEmptyState=\(libraryItems.friendRecommendationsEmptyState?.rawValue ?? "nil") " +
            "likedGamesCount=\(libraryItems.likedGames.count) " +
            "reviewsCount=\(libraryItems.reviews.count) " +
            "isSteamConnected=\(steamState.isConnected) " +
            "steamSyncStatus=\(steamState.syncStatus.rawValue) " +
            "isSteamSyncAvailable=\(steamState.isSyncAvailable)"
        )
    }

    @MainActor
    private func logCurrentMappedState(id: Int) {
        print(
            "[Library] mappedState id=\(id) " +
            "recentlyPlayedCount=\(state.recentlyPlayed.count) " +
            "playingGamesCount=\(state.playingGames.count) " +
            "ownedGamesCount=\(state.ownedGames.count) " +
            "backlogGamesCount=\(state.backlogGames.count) " +
            "playtimeRecommendationsCount=\(state.playtimeRecommendations.count) " +
            "friendRecommendationsCount=\(state.friendRecommendations.count) " +
            "friendRecommendationsSource=\(state.friendRecommendationsSource.rawValue) " +
            "friendRecommendationsEmptyState=\(state.friendRecommendationsEmptyState?.rawValue ?? "nil") " +
            "likedGamesCount=\(state.likedGames.count) " +
            "reviewsCount=\(state.reviews.count) " +
            "isSteamConnected=\(state.isSteamConnected) " +
            "steamSyncStatus=\(state.steamSyncStatus.rawValue) " +
            "isSteamSyncAvailable=\(state.isSteamSyncAvailable)"
        )
    }

    private func handleSteamLinkCallbackResult(_ result: SteamLinkCallbackResult) {
        switch result.status {
        case .success:
            apply(.clearError)
            shouldPresentSteamPrivacyGuidanceAfterSteamLink = true
            shouldPresentSteamConnectionOnboardingAfterSteamLink = true
            shouldEvaluateAutomaticSilentSteamSyncAfterNextOverviewLoad = true
            refreshSteamLinkStatus()
        case .failed, .cancelled:
            apply(
                .setError(
                    result.userFacingMessage
                    ?? "Steam 연동을 완료하지 못했어요. 잠시 후 다시 시도해주세요."
                )
            )
        }
    }

    private func refreshSteamLinkStatus() {
        if state.isLoading || state.isRefreshing {
            needsSteamLinkStatusRefresh = true
            return
        }

        isRefreshingSteamLinkStatus = true
        print("[SteamLink] statusRefreshStarted")
        loadLibrary(trigger: .refresh)
    }

    private func maybePresentSteamPrivacyGuidanceAfterSteamLink(
        steamState: (
            steamLinkStatus: SteamLinkStatus,
            isConnected: Bool,
            syncStatus: SteamSyncStatus,
            isSyncAvailable: Bool,
            errorCode: String?
        )
    ) {
        if shouldPresentSteamConnectionOnboardingAfterSteamLink,
           steamState.isConnected,
           !libraryCacheStore.hasShownSteamConnectionOnboarding(),
           shouldPresentSteamPrivacyGuidance(
                isConnected: steamState.isConnected,
                syncStatus: steamState.syncStatus,
                errorCode: steamState.errorCode
           ) == false {
            shouldPresentSteamConnectionOnboardingAfterSteamLink = false
            libraryCacheStore.markSteamConnectionOnboardingShown()
            apply(
                .setSteamConnectionOnboarding(
                    LibraryOnboardingViewState(
                        title: "Steam 연동 완료",
                        message: "보유 게임과 최근 플레이 정보를 불러오는 중이에요.",
                        helperText: "연동된 게임은 자동으로 업데이트돼요."
                    )
                )
            )
        }

        guard shouldPresentSteamPrivacyGuidanceAfterSteamLink else { return }
        guard !needsSteamLinkStatusRefresh, !isRefreshingSteamLinkStatus else { return }
        shouldPresentSteamPrivacyGuidanceAfterSteamLink = false
        shouldPresentSteamConnectionOnboardingAfterSteamLink = false

        guard shouldPresentSteamPrivacyGuidance(
            isConnected: steamState.isConnected,
            syncStatus: steamState.syncStatus,
            errorCode: steamState.errorCode
        ) else {
            return
        }

        print(
            "[SteamPrivacyGuide] " +
            "present reason=steam_link_completed " +
            "errorCode=\(steamState.errorCode ?? "nil")"
        )
        showSteamPrivacyGuide(reason: "steam_link_completed")
    }

    private func resolveSteamState(
        from result: Result<LibraryOverview, Error>,
        fallback: (
            steamLinkStatus: SteamLinkStatus,
            isConnected: Bool,
            syncStatus: SteamSyncStatus,
            isSyncAvailable: Bool,
            errorCode: String?
        )
    ) -> (
        steamLinkStatus: SteamLinkStatus,
        isConnected: Bool,
        syncStatus: SteamSyncStatus,
        isSyncAvailable: Bool,
        errorCode: String?
    ) {
        guard case .success(let overview) = result else { return fallback }
        return (
            steamLinkStatus: overview.steamLinkStatus,
            isConnected: overview.steamLinkStatus.isLinked,
            syncStatus: overview.steamSyncStatus,
            isSyncAvailable: overview.isSteamSyncAvailable,
            errorCode: overview.steamSyncErrorCode
        )
    }

    private func resolveLibraryItems(
        overviewResult: Result<LibraryOverview, Error>,
        wishlistResult: Result<[FavoriteGameEntry], Error>,
        reviewedResult: Result<[ReviewedGame], Error>
    ) -> (
        recentlyPlayed: [LibraryGameSummary],
        playingGames: [LibraryGameSummary],
        ownedGames: [LibraryGameSummary],
        backlogGames: [LibraryGameSummary],
        likedGames: [Game],
        reviews: [ReviewedGame]
    ) {
        let recentlyPlayed: [LibraryGameSummary]
        let playingGames: [LibraryGameSummary]
        let ownedGames: [LibraryGameSummary]
        let backlogGames: [LibraryGameSummary]
        if case .success(let overview) = overviewResult {
            recentlyPlayed = overview.recentlyPlayed
            playingGames = overview.playing
            ownedGames = overview.owned
            backlogGames = overview.backlog
        } else {
            recentlyPlayed = []
            playingGames = []
            ownedGames = []
            backlogGames = []
        }

        let likedGames: [Game]
        if case .success(let wishlist) = wishlistResult {
            likedGames = wishlist.map(\.game)
        } else {
            likedGames = []
        }

        let reviews: [ReviewedGame]
        if case .success(let reviewedGames) = reviewedResult {
            reviews = reviewedGames
        } else {
            reviews = []
        }

        return (
            recentlyPlayed: recentlyPlayed,
            playingGames: playingGames,
            ownedGames: ownedGames,
            backlogGames: backlogGames,
            likedGames: likedGames,
            reviews: reviews
        )
    }

    private func makeAddToPlayingRequest(from summary: LibraryGameSummary) -> LibraryGameStatusUpdateRequest? {
        guard let externalGameId = sanitized(summary.identifier.sourceID),
              let title = sanitized(summary.title),
              title != "이름 없는 게임" else {
            return nil
        }

        if summary.identifier.source == .steam, Int(externalGameId) == nil {
            return nil
        }

        return LibraryGameStatusUpdateRequest(
            identifier: summary.identifier,
            title: title,
            coverImageURL: summary.coverImageURL,
            status: .playing
        )
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func isSteamRecentlyPlayedUnavailable(
        syncStatus: SteamSyncStatus,
        errorCode: String?
    ) -> Bool {
        if syncStatus == .privateProfile {
            return true
        }

        guard let errorCode = sanitized(errorCode)?.uppercased() else { return false }

        switch errorCode {
        case "STEAM_RECENTLY_PLAYED_UNAVAILABLE",
             "STEAM_PROFILE_PRIVATE",
             "STEAM_GAME_DETAILS_PRIVATE":
            return true
        default:
            return false
        }
    }

    private func isSteamSyncInProgress(syncStatus: SteamSyncStatus) -> Bool {
        syncStatus == .syncing
    }

    private func isSteamTokenExpired(syncStatus: SteamSyncStatus, errorCode: String?) -> Bool {
        if syncStatus == .tokenExpired {
            return true
        }

        guard let errorCode = sanitized(errorCode)?.uppercased() else { return false }
        return errorCode == "STEAM_TOKEN_EXPIRED"
    }

    private func isSteamSyncFailed(
        syncStatus: SteamSyncStatus,
        isSyncAvailable: Bool,
        errorCode: String?
    ) -> Bool {
        if isSteamTokenExpired(syncStatus: syncStatus, errorCode: errorCode)
            || syncStatus == .privateProfile
            || syncStatus == .success {
            return false
        }

        if isNonBlockingSteamMetadataIssue(errorCode: errorCode) {
            return false
        }

        if syncStatus == .failed {
            return true
        }

        return !isSyncAvailable
    }

    private func isSteamOwnedLibraryUnavailable(errorCode: String?) -> Bool {
        guard let errorCode = sanitized(errorCode)?.uppercased() else { return false }
        return errorCode == "STEAM_OWNED_GAMES_UNAVAILABLE"
    }

    private func isSteamOwnedLibraryPrivacyUnavailable(errorCode: String?) -> Bool {
        guard let errorCode = sanitized(errorCode)?.uppercased() else { return false }

        switch errorCode {
        case "STEAM_OWNED_GAMES_UNAVAILABLE",
             "STEAM_PROFILE_PRIVATE",
             "STEAM_GAME_DETAILS_PRIVATE":
            return true
        default:
            return false
        }
    }

    private func isSteamOwnedLibrarySyncFailed(errorCode: String?) -> Bool {
        guard let errorCode = sanitized(errorCode)?.uppercased() else { return false }
        if isNonBlockingSteamMetadataIssue(errorCode: errorCode) {
            return false
        }
        return errorCode == "STEAM_SYNC_FAILED"
    }

    private func isNonBlockingSteamMetadataIssue(errorCode: String?) -> Bool {
        guard let normalizedCode = sanitized(errorCode)?.uppercased() else { return false }

        return normalizedCode.contains("IGDB")
            || normalizedCode.contains("RATE_LIMIT")
            || normalizedCode.contains("TIMEOUT")
            || normalizedCode.contains("ENRICHMENT_PENDING")
    }

    private func resolveOwnedSyncInlineErrorCode(from error: Error) -> String {
        let libraryError = LibraryError.from(error: error)

        switch libraryError {
        case .server(let code, _):
            let normalizedCode = code.uppercased()
            if isSteamOwnedLibraryPrivacyUnavailable(errorCode: normalizedCode) {
                return normalizedCode
            }
            return "STEAM_SYNC_FAILED"
        case .network, .invalidResponse, .unknown:
            return "STEAM_SYNC_FAILED"
        case .unauthorized, .invalidGameIdentifier, .invalidStatus:
            return "STEAM_SYNC_FAILED"
        }
    }

    private func shouldPresentSteamPrivacyGuidance(
        isConnected: Bool,
        syncStatus: SteamSyncStatus,
        errorCode: String?
    ) -> Bool {
        guard isConnected else { return false }
        return isSteamRecentlyPlayedUnavailable(syncStatus: syncStatus, errorCode: errorCode)
            || isSteamOwnedLibraryUnavailable(errorCode: errorCode)
    }

    private func resolveSyncOwnedSteamLibraryErrorMessage(_ error: Error) -> String {
        let libraryError = LibraryError.from(error: error)

        switch libraryError {
        case .server(let code, let message):
            let normalizedCode = code.uppercased()
            let normalizedMessage = message.lowercased()

            if normalizedCode == "STEAM_ACCOUNT_NOT_LINKED" {
                return "Steam 계정을 먼저 연결해주세요."
            }

            if normalizedCode == "STEAM_OWNED_GAMES_UNAVAILABLE" {
                return "Steam 공개 설정 때문에 보관함 정보를 가져올 수 없어요."
            }

            if normalizedCode == "STEAM_API_NOT_CONFIGURED"
                || normalizedCode == "CONFIGURATION_MISSING"
                || normalizedMessage.contains("not configured")
                || normalizedMessage.contains("configuration") {
                return "현재 Steam 보관함 연동이 서버에 아직 설정되어 있지 않아요."
            }

            return message
        case .network:
            return "Steam 보관함을 가져오지 못했어요. 잠시 후 다시 시도해주세요."
        case .invalidResponse:
            return "Steam 보관함 응답을 처리하지 못했어요. 잠시 후 다시 시도해주세요."
        default:
            return libraryError.errorDescription ?? "Steam 보관함을 가져오지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    private func resolveSteamLinkErrorMessage(_ error: Error) -> String {
        let libraryError = LibraryError.from(error: error)

        switch libraryError {
        case .server(let code, let message):
            let normalizedMessage = message.lowercased()
            if code == "CONFIGURATION_MISSING"
                || normalizedMessage.contains("not configured")
                || normalizedMessage.contains("configuration")
                || message.contains("설정") {
                return "현재 Steam 연동이 서버에 아직 설정되어 있지 않아요."
            }
            return "Steam 연동을 시작할 수 없어요. 잠시 후 다시 시도해주세요."
        case .network:
            return "Steam 서버와 통신하지 못했어요. 잠시 후 다시 시도해주세요."
        case .invalidResponse:
            return "Steam 연동을 시작할 수 없어요. 잠시 후 다시 시도해주세요."
        default:
            return libraryError.errorDescription ?? "Steam 연동을 시작할 수 없어요. 잠시 후 다시 시도해주세요."
        }
    }

    private func resolveSteamUnlinkErrorMessage(_ error: Error) -> String {
        let libraryError = LibraryError.from(error: error)

        switch libraryError {
        case .network:
            return "Steam 연동을 해제하지 못했어요. 잠시 후 다시 시도해주세요."
        case .invalidResponse:
            return "Steam 연동 해제 응답을 처리하지 못했어요. 잠시 후 다시 시도해주세요."
        case .server(_, let message):
            return message
        default:
            return libraryError.errorDescription ?? "Steam 연동을 해제하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }

    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
