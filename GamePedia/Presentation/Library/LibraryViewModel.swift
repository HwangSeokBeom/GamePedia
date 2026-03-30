import Combine
import Foundation

final class LibraryViewModel {
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
    }

    private(set) var state: LibraryState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((LibraryState) -> Void)?
    var onRoute: ((LibraryRoute) -> Void)?

    private let fetchLibraryOverviewUseCase: FetchLibraryOverviewUseCase
    private let fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase
    private let fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase
    private let startSteamLinkUseCase: StartSteamLinkUseCase
    private let syncOwnedSteamLibraryUseCase: SyncOwnedSteamLibraryUseCase
    private let updateLibraryGameStatusUseCase: UpdateLibraryGameStatusUseCase
    private let removeFavoriteUseCase: RemoveFavoriteUseCase
    private let translateTextUseCase: TranslateTextUseCase
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var fetchSequence = 0
    private var isRefreshingSteamLinkStatus = false
    private var needsSteamLinkStatusRefresh = false
    private var shouldPresentSteamPrivacyGuidanceAfterSteamLink = false

    init(
        fetchLibraryOverviewUseCase: FetchLibraryOverviewUseCase = FetchLibraryOverviewUseCase(
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
        startSteamLinkUseCase: StartSteamLinkUseCase = StartSteamLinkUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        syncOwnedSteamLibraryUseCase: SyncOwnedSteamLibraryUseCase = SyncOwnedSteamLibraryUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        updateLibraryGameStatusUseCase: UpdateLibraryGameStatusUseCase = UpdateLibraryGameStatusUseCase(
            libraryRepository: DefaultLibraryRepository()
        ),
        initialTab: LibraryTab = .favorites,
        removeFavoriteUseCase: RemoveFavoriteUseCase = RemoveFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        translateTextUseCase: TranslateTextUseCase = DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        )
    ) {
        self.state = LibraryState(pendingFocusSection: initialTab.focusedSection)
        self.fetchLibraryOverviewUseCase = fetchLibraryOverviewUseCase
        self.fetchFavoriteGamesUseCase = fetchFavoriteGamesUseCase
        self.fetchMyReviewedGamesUseCase = fetchMyReviewedGamesUseCase
        self.startSteamLinkUseCase = startSteamLinkUseCase
        self.syncOwnedSteamLibraryUseCase = syncOwnedSteamLibraryUseCase
        self.updateLibraryGameStatusUseCase = updateLibraryGameStatusUseCase
        self.removeFavoriteUseCase = removeFavoriteUseCase
        self.translateTextUseCase = translateTextUseCase
        observeLibraryChanges()
    }

    func send(_ intent: LibraryIntent) {
        switch intent {
        case .viewDidLoad:
            guard state.sections.isEmpty else {
                print("[Library] viewDidLoad ignored reason=sectionsAlreadyLoaded")
                return
            }
            loadLibrary(trigger: .initial)

        case .pullToRefresh:
            loadLibrary(trigger: .refresh)

        case .didSelectSort(let index):
            let selectedSort: LibrarySortOption = index == 1 ? .oldest : .latest
            guard selectedSort != state.selectedSort else { return }
            apply(.setSort(selectedSort))
            loadLibrary(trigger: .refresh)

        case .syncOwnedSteamLibraryButtonTapped:
            syncOwnedSteamLibrary()

        case .connectSteamButtonTapped:
            startSteamLink()

        case .steamPrivacyGuideButtonTapped:
            showSteamPrivacyGuide(reason: "manual")

        case .retrySteamPrivacyGuideTapped:
            retrySteamPrivacyGuidance()

        case .retrySteamSyncTapped:
            loadLibrary(trigger: .refresh)

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

        case .didTapReviewedGame(let identifier):
            routeToGameDetailIfPossible(identifier)

        case .didTapSeeAllRecentlyPlayed:
            if let route = makeSectionListRoute(for: .recentlyPlayed) {
                onRoute?(.showSectionList(route))
            }

        case .didTapSeeAllPlaying:
            if let route = makeSectionListRoute(for: .playing) {
                onRoute?(.showSectionList(route))
            }

        case .didTapSeeAllOwned:
            if let route = makeSectionListRoute(for: .owned) {
                onRoute?(.showSectionList(route))
            }

        case .didTapSeeAllReviewed:
            onRoute?(.showReviewed)

        case .didConfirmRemoveFavorite(let identifier):
            removeFavorite(identifier)

        case .didConsumeSuccessMessage:
            apply(.clearSuccessMessage)

        case .didConsumeInitialFocus:
            apply(.consumeInitialFocus)
        }
    }

    private func apply(_ mutation: LibraryMutation) {
        state = LibraryReducer.reduce(state, mutation)
    }

    private func loadLibrary(trigger: LoadTrigger) {
        guard !state.isLoading && !state.isRefreshing else {
            print("[Library] fetchSkipped trigger=\(trigger.logName) reason=requestInFlight")
            return
        }

        loadTask?.cancel()
        apply(.clearError)

        switch trigger {
        case .initial:
            apply(.setLoading(true))
        case .refresh:
            apply(.setRefreshing(true))
        }

        let selectedSort = state.selectedSort
        fetchSequence += 1
        let fetchID = fetchSequence
        print("[Library] fetchStarted id=\(fetchID) trigger=\(trigger.logName) sort=\(selectedSort)")
        let previousSteamState = (
            isConnected: state.isSteamConnected,
            isSyncAvailable: state.isSteamSyncAvailable,
            errorCode: state.steamSyncErrorCode
        )
        loadTask = Task { [weak self] in
            guard let self else { return }

            async let overviewResult = self.captureResult {
                try await self.fetchLibraryOverviewUseCase.execute(sort: selectedSort.userGameSort)
            }
            async let wishlistResult = self.captureResult {
                try await self.fetchFavoriteGamesUseCase.execute(sort: selectedSort.favoriteSort)
            }
            async let reviewedResult = self.captureResult {
                try await self.fetchMyReviewedGamesUseCase.execute(sort: selectedSort.reviewSort)
            }

            let resolvedOverviewResult = await overviewResult
            let resolvedWishlistResult = await wishlistResult
            let resolvedReviewedResult = await reviewedResult

            if Task.isCancelled { return }

            let translatedOverview = await self.translatedOverview(from: resolvedOverviewResult)
            let translatedWishlist = await self.translatedWishlist(from: resolvedWishlistResult)
            let translatedReviewed = await self.translatedReviewed(from: resolvedReviewedResult)

            if Task.isCancelled { return }

            self.logResponseSummary(
                id: fetchID,
                overviewResult: translatedOverview,
                wishlistResult: translatedWishlist,
                reviewedResult: translatedReviewed
            )

            let sections = self.makeSections(
                overviewResult: translatedOverview,
                wishlistResult: translatedWishlist,
                reviewedResult: translatedReviewed
            )
            let errorMessage = self.resolveErrorMessage(
                overviewResult: translatedOverview,
                wishlistResult: translatedWishlist,
                reviewedResult: translatedReviewed
            )
            let steamState = self.resolveSteamState(
                from: translatedOverview,
                fallback: previousSteamState
            )
            let libraryItems = self.resolveLibraryItems(
                overviewResult: translatedOverview,
                wishlistResult: translatedWishlist,
                reviewedResult: translatedReviewed
            )
            self.logMappedState(
                id: fetchID,
                libraryItems: libraryItems,
                steamState: steamState
            )

            await MainActor.run {
                self.apply(
                    .setSteamState(
                        isConnected: steamState.isConnected,
                        isSyncAvailable: steamState.isSyncAvailable,
                        errorCode: steamState.errorCode
                    )
                )
                self.apply(
                    .setLibraryItems(
                        recentlyPlayed: libraryItems.recentlyPlayed,
                        playingGames: libraryItems.playingGames,
                        ownedGames: libraryItems.ownedGames,
                        backlogGames: libraryItems.backlogGames,
                        likedGames: libraryItems.likedGames,
                        reviews: libraryItems.reviews
                    )
                )
                self.apply(.setSections(sections))
                self.apply(.clearAddingToPlaying)
                self.apply(.setLoading(false))
                self.apply(.setRefreshing(false))
                if let errorMessage {
                    self.apply(.setError(errorMessage))
                } else {
                    self.apply(.clearError)
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

    private func routeToGameDetailIfPossible(_ identifier: LibraryGameIdentifier) {
        guard let gameID = identifier.detailGameID else {
            print("[Library] detailUnavailable identifier=\(identifier.uniqueKey)")
            apply(.clearError)
            apply(.setError("게임 상세 정보를 아직 불러올 수 없어요."))
            return
        }
        onRoute?(.showGameDetail(gameID))
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

    private func showSteamPrivacyGuide(reason: String) {
        guard let settingsURL = SteamPrivacyGuideContent.settingsURL else {
            apply(.setError("Steam 설정 페이지를 열 수 없어요. 잠시 후 다시 시도해주세요."))
            return
        }

        print("[SteamPrivacyGuide] present reason=\(reason)")
        onRoute?(.showSteamPrivacyGuide(settingsURL))
    }

    private func syncOwnedSteamLibrary() {
        guard !state.isSyncingOwnedSteamLibrary else { return }

        guard state.isSteamConnected else {
            apply(.clearError)
            apply(.setError("Steam 계정을 먼저 연결해주세요."))
            return
        }

        apply(.clearError)
        apply(.clearSuccessMessage)
        apply(.setSyncingOwnedSteamLibrary(true))
        print("[Library] syncOwnedSteamLibrary started")

        Task {
            do {
                let result = try await syncOwnedSteamLibraryUseCase.execute()
                await MainActor.run {
                    self.apply(.setSyncingOwnedSteamLibrary(false))

                    if self.isSteamOwnedLibraryUnavailable(errorCode: result.syncWarningCode) {
                        print(
                            "[SteamPrivacyGuide] " +
                            "present reason=owned_library_sync_unavailable " +
                            "errorCode=\(result.syncWarningCode ?? "nil")"
                        )
                        self.showSteamPrivacyGuide(reason: "owned_library_sync_unavailable")
                        self.loadLibrary(trigger: .refresh)
                        return
                    }

                    let successMessage: String
                    if result.isRateLimitedIGDBEnrichmentPartialSuccess {
                        successMessage = "Steam 보관함을 가져왔어요\n일부 게임 정보 보강은 잠시 후 다시 시도될 수 있어요."
                    } else {
                        successMessage = "Steam 보관함을 가져왔어요"
                    }

                    self.apply(.setSuccessMessage(successMessage))
                    self.loadLibrary(trigger: .refresh)
                }
            } catch {
                let errorMessage = resolveSyncOwnedSteamLibraryErrorMessage(error)
                await MainActor.run {
                    self.apply(.setSyncingOwnedSteamLibrary(false))
                    self.apply(.setError(errorMessage))
                }
            }
        }
    }

    private func retrySteamPrivacyGuidance() {
        guard state.isSteamConnected else {
            loadLibrary(trigger: .refresh)
            return
        }

        guard !state.isSyncingOwnedSteamLibrary else { return }
        apply(.clearError)
        apply(.setSyncingOwnedSteamLibrary(true))
        print("[SteamPrivacyGuide] retryRequested")

        Task {
            do {
                let result = try await syncOwnedSteamLibraryUseCase.execute()
                await MainActor.run {
                    self.apply(.setSyncingOwnedSteamLibrary(false))
                    print(
                        "[SteamPrivacyGuide] " +
                        "retryCompleted warningCode=\(result.syncWarningCode ?? "nil")"
                    )
                    self.loadLibrary(trigger: .refresh)
                }
            } catch {
                let errorMessage = resolveSyncOwnedSteamLibraryErrorMessage(error)
                await MainActor.run {
                    self.apply(.setSyncingOwnedSteamLibrary(false))
                    self.apply(.setError(errorMessage))
                }
            }
        }
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
                    )
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
        wishlistResult: Result<[FavoriteGameEntry], Error>,
        reviewedResult: Result<[ReviewedGame], Error>
    ) -> [LibrarySectionViewState] {
        let playingIdentifiers = playingIdentifierSet(from: overviewResult)

        return [
            makeRecentlyPlayedSection(from: overviewResult, playingIdentifiers: playingIdentifiers),
            makePlayingSection(from: overviewResult),
            makeOwnedSection(from: overviewResult),
            makeWishlistSection(from: wishlistResult),
            makeReviewedSection(from: reviewedResult)
        ]
    }

    private func makeSectionListRoute(for kind: LibrarySectionKind) -> LibrarySectionListRoute? {
        switch kind {
        case .recentlyPlayed:
            guard !state.recentlyPlayed.isEmpty else { return nil }
            let playingIdentifiers = Set(state.playingGames.map(\.identifier))
            return LibrarySectionListRoute(
                kind: .recentlyPlayed,
                layoutStyle: .recentCards,
                items: makeRecentlyPlayedItems(
                    summaries: state.recentlyPlayed,
                    playingIdentifiers: playingIdentifiers,
                    limit: nil,
                    showsAddToPlayingAction: false
                )
            )

        case .playing:
            guard !state.playingGames.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .playing,
                layoutStyle: .list,
                items: makeLibraryRowItems(
                    summaries: state.playingGames,
                    limit: nil
                )
            )

        case .owned:
            guard !state.ownedGames.isEmpty else { return nil }
            return LibrarySectionListRoute(
                kind: .owned,
                layoutStyle: .list,
                items: makeLibraryRowItems(
                    summaries: state.ownedGames,
                    limit: nil
                )
            )

        case .wishlist, .reviewed:
            return nil
        }
    }

    private func makeRecentlyPlayedItems(
        summaries: [LibraryGameSummary],
        playingIdentifiers: Set<LibraryGameIdentifier>,
        limit: Int?,
        showsAddToPlayingAction: Bool
    ) -> [LibraryCollectionItem] {
        let limitedSummaries = limitedLibrarySummaries(summaries, limit: limit)

        return limitedSummaries.map { summary in
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
                    title: summary.displayTitle,
                    metadataText: recentlyPlayedMetadataText(for: summary),
                    ratingText: summary.rating.map { String(format: "%.1f", $0) },
                    coverImageURL: summary.coverImageURL,
                    fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                    badgeText: "Steam",
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
            let subtitleText = librarySubtitleText(for: summary)
            return LibraryCollectionItem.row(
                LibraryGameRowViewState(
                    identifier: summary.identifier,
                    title: summary.displayTitle,
                    subtitleText: subtitleText,
                    metadataText: libraryRowMetadataText(for: summary, subtitleText: subtitleText),
                    coverImageURL: summary.coverImageURL,
                    fallbackCoverImageURLs: summary.fallbackCoverImageURLs,
                    ratingText: summary.rating.map { String(format: "%.1f", $0) },
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

    private func recentlyPlayedMetadataText(for summary: LibraryGameSummary) -> String {
        if let recentPlaytimeText = sanitized(summary.recentPlaytimeText) {
            return recentPlaytimeText
        }

        if let subtitleText = conciseLibraryMetadataText(for: summary) {
            return subtitleText
        }

        return steamLibraryFallbackText(for: summary)
    }

    private func librarySubtitleText(for summary: LibraryGameSummary) -> String {
        conciseLibraryMetadataText(for: summary) ?? steamLibraryFallbackText(for: summary)
    }

    private func libraryRowMetadataText(
        for summary: LibraryGameSummary,
        subtitleText: String
    ) -> String {
        guard let platformText = normalizedPlatformText(for: summary),
              subtitleText.contains(platformText) == false else {
            return ""
        }

        return platformText
    }

    private func conciseLibraryMetadataText(for summary: LibraryGameSummary) -> String? {
        let components = [
            normalizedGenreText(for: summary),
            knownReleaseText(for: summary)
        ].compactMap { $0 }

        guard !components.isEmpty else { return nil }
        return components.joined(separator: " · ")
    }

    private func normalizedGenreText(for summary: LibraryGameSummary) -> String? {
        guard let genreText = sanitized(summary.genre),
              genreText != "기타" else {
            return nil
        }

        return genreText
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

        return summary.identifier.detailGameID == nil ? "Steam · 정보 보강 중" : "Steam"
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
            if !overview.steamLinkStatus.isLinked {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.connect",
                                style: .banner,
                                title: "Steam 계정을 연결하세요",
                                message: "Steam 계정을 연결하면 최근 플레이한 게임을 자동으로 불러올 수 있어요.",
                                detailText: nil,
                                buttonTitle: "Steam 계정 연동하기",
                                action: .connectSteam
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if isSteamRecentlyPlayedUnavailable(errorCode: overview.steamSyncErrorCode) {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.privacyUnavailable",
                                style: .error,
                                title: "최근 플레이한 게임 정보를 불러올 수 없어요",
                                message: "Steam 공개 설정 때문에 최근 플레이 정보를 가져올 수 없어요.",
                                detailText: "Steam > 프로필 편집 > 공개 설정에서 프로필과 게임 세부 정보를 공개로 변경해주세요.",
                                buttonTitle: "설정 방법 보기",
                                action: .showSteamPrivacyGuide
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if !overview.isSteamSyncAvailable {
                return LibrarySectionViewState(
                    kind: .recentlyPlayed,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "recentlyPlayed.unavailable",
                                style: .error,
                                title: "Steam 정보를 불러올 수 없어요",
                                message: "현재 Steam 데이터를 동기화할 수 없는 상태예요. 잠시 후 다시 시도해주세요.",
                                detailText: overview.steamSyncErrorCode.map { "오류 코드: \($0)" },
                                buttonTitle: "다시 시도",
                                action: .retrySteamSync
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            if overview.recentlyPlayed.isEmpty {
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
                                buttonTitle: "라이브러리 새로고침",
                                action: .retrySteamSync
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
                    summaries: overview.recentlyPlayed,
                    playingIdentifiers: playingIdentifiers,
                    limit: PreviewLimit.recentCards,
                    showsAddToPlayingAction: true
                ),
                showsSeeAll: overview.recentlyPlayed.count > PreviewLimit.recentCards
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
                showsSeeAll: overview.playing.count > PreviewLimit.listRows
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

            let items = wishlist.map { entry in
                LibraryCollectionItem.row(
                    LibraryGameRowViewState(
                        identifier: LibraryGameIdentifier(
                            source: .igdb,
                            sourceID: String(entry.game.id),
                            canonicalGameID: entry.game.id
                        ),
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
                showsSeeAll: false
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
            if overview.owned.isEmpty {
                return LibrarySectionViewState(
                    kind: .owned,
                    layoutStyle: .message,
                    items: [
                        .message(
                            LibraryMessageViewState(
                                id: "owned.empty",
                                style: .empty,
                                title: nil,
                                message: "가져온 보유 게임이 아직 없어요.",
                                detailText: "상단의 Steam 보관함 가져오기를 눌러 보유 게임을 불러올 수 있어요.",
                                buttonTitle: nil,
                                action: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            return LibrarySectionViewState(
                kind: .owned,
                layoutStyle: .list,
                items: makeLibraryRowItems(
                    summaries: overview.owned,
                    limit: PreviewLimit.listRows
                ),
                showsSeeAll: overview.owned.count > PreviewLimit.listRows
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

            let items = reviewedGames.map { reviewedGame in
                LibraryCollectionItem.row(
                    LibraryGameRowViewState(
                        identifier: LibraryGameIdentifier(
                            source: .igdb,
                            sourceID: String(reviewedGame.gameId),
                            canonicalGameID: reviewedGame.gameId
                        ),
                        title: reviewedGame.game.displayTitle,
                        subtitleText: reviewedGame.contentPreview,
                        metadataText: "\(reviewedGame.game.genre) · \(releaseText(for: reviewedGame.game.releaseYear))",
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
                showsSeeAll: false
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
        wishlistResult: Result<[FavoriteGameEntry], Error>,
        reviewedResult: Result<[ReviewedGame], Error>
    ) -> String? {
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

    private func logResponseSummary(
        id: Int,
        overviewResult: Result<LibraryOverview, Error>,
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

        print("[Library] responseArrived id=\(id) \(overviewSummary) \(wishlistSummary) \(reviewedSummary)")
    }

    private func logMappedState(
        id: Int,
        libraryItems: (
            recentlyPlayed: [LibraryGameSummary],
            playingGames: [LibraryGameSummary],
            ownedGames: [LibraryGameSummary],
            backlogGames: [LibraryGameSummary],
            likedGames: [Game],
            reviews: [ReviewedGame]
        ),
        steamState: (isConnected: Bool, isSyncAvailable: Bool, errorCode: String?)
    ) {
        print(
            "[Library] mappedState id=\(id) " +
            "recentlyPlayedCount=\(libraryItems.recentlyPlayed.count) " +
            "playingGamesCount=\(libraryItems.playingGames.count) " +
            "ownedGamesCount=\(libraryItems.ownedGames.count) " +
            "backlogGamesCount=\(libraryItems.backlogGames.count) " +
            "likedGamesCount=\(libraryItems.likedGames.count) " +
            "reviewsCount=\(libraryItems.reviews.count) " +
            "isSteamConnected=\(steamState.isConnected) " +
            "isSteamSyncAvailable=\(steamState.isSyncAvailable)"
        )
    }

    private func handleSteamLinkCallbackResult(_ result: SteamLinkCallbackResult) {
        switch result.status {
        case .success:
            apply(.clearError)
            shouldPresentSteamPrivacyGuidanceAfterSteamLink = true
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
        steamState: (isConnected: Bool, isSyncAvailable: Bool, errorCode: String?)
    ) {
        guard shouldPresentSteamPrivacyGuidanceAfterSteamLink else { return }
        guard !needsSteamLinkStatusRefresh, !isRefreshingSteamLinkStatus else { return }
        shouldPresentSteamPrivacyGuidanceAfterSteamLink = false

        guard shouldPresentSteamPrivacyGuidance(
            isConnected: steamState.isConnected,
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
        fallback: (isConnected: Bool, isSyncAvailable: Bool, errorCode: String?)
    ) -> (isConnected: Bool, isSyncAvailable: Bool, errorCode: String?) {
        guard case .success(let overview) = result else { return fallback }
        return (
            isConnected: overview.steamLinkStatus.isLinked,
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

    private func isSteamRecentlyPlayedUnavailable(errorCode: String?) -> Bool {
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

    private func isSteamOwnedLibraryUnavailable(errorCode: String?) -> Bool {
        guard let errorCode = sanitized(errorCode)?.uppercased() else { return false }
        return errorCode == "STEAM_OWNED_GAMES_UNAVAILABLE"
    }

    private func shouldPresentSteamPrivacyGuidance(
        isConnected: Bool,
        errorCode: String?
    ) -> Bool {
        guard isConnected else { return false }
        return isSteamRecentlyPlayedUnavailable(errorCode: errorCode)
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
}

private extension Result {
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
