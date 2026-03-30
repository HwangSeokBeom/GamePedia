import Combine
import Foundation

final class LibraryViewModel {
    private enum LoadTrigger {
        case initial
        case refresh
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
    private let updateLibraryGameStatusUseCase: UpdateLibraryGameStatusUseCase
    private let removeFavoriteUseCase: RemoveFavoriteUseCase
    private let translateTextUseCase: TranslateTextUseCase
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

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
        self.updateLibraryGameStatusUseCase = updateLibraryGameStatusUseCase
        self.removeFavoriteUseCase = removeFavoriteUseCase
        self.translateTextUseCase = translateTextUseCase
        observeLibraryChanges()
    }

    func send(_ intent: LibraryIntent) {
        switch intent {
        case .viewDidLoad:
            guard state.sections.isEmpty else { return }
            loadLibrary(trigger: .initial)

        case .pullToRefresh:
            loadLibrary(trigger: .refresh)

        case .didSelectSort(let index):
            let selectedSort: LibrarySortOption = index == 1 ? .oldest : .latest
            guard selectedSort != state.selectedSort else { return }
            apply(.setSort(selectedSort))
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
            onRoute?(.showRecentlyPlayed)

        case .didTapSeeAllReviewed:
            onRoute?(.showReviewed)

        case .didConfirmRemoveFavorite(let identifier):
            removeFavorite(identifier)

        case .didConsumeInitialFocus:
            apply(.consumeInitialFocus)
        }
    }

    private func apply(_ mutation: LibraryMutation) {
        state = LibraryReducer.reduce(state, mutation)
    }

    private func loadLibrary(trigger: LoadTrigger) {
        guard !state.isLoading && !state.isRefreshing else { return }

        loadTask?.cancel()
        apply(.clearError)

        switch trigger {
        case .initial:
            apply(.setLoading(true))
        case .refresh:
            apply(.setRefreshing(true))
        }

        let selectedSort = state.selectedSort
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

            await MainActor.run {
                self.apply(.setSections(sections))
                self.apply(.setLoading(false))
                self.apply(.setRefreshing(false))
                if let errorMessage {
                    self.apply(.setError(errorMessage))
                } else {
                    self.apply(.clearError)
                }
            }
        }
    }

    private func routeToGameDetailIfPossible(_ identifier: LibraryGameIdentifier) {
        guard let gameID = identifier.detailGameID else { return }
        onRoute?(.showGameDetail(gameID))
    }

    private func startSteamLink() {
        apply(.clearError)
        print("[LibrarySteamLink] action=didTapSteamLink")

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

    private func addToPlaying(_ identifier: LibraryGameIdentifier) {
        guard !state.isLoading else { return }

        Task {
            do {
                _ = try await updateLibraryGameStatusUseCase.execute(identifier: identifier, status: .playing)
                await MainActor.run {
                    self.loadLibrary(trigger: .refresh)
                }
            } catch {
                let libraryError = LibraryError.from(error: error)
                await MainActor.run {
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
                self?.loadLibrary(trigger: .refresh)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .reviewDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
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
                    recentlyPlayed: translatedRecentlyPlayed,
                    playing: translatedPlaying
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
            makeWishlistSection(from: wishlistResult),
            makeReviewedSection(from: reviewedResult)
        ]
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
                                id: "recentlyPlayed.banner",
                                style: .banner,
                                title: nil,
                                message: "Steam 계정을 연결하면 최근 플레이한 게임을 자동으로 불러올 수 있어요.",
                                buttonTitle: "Steam 연동하기"
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
                                title: nil,
                                message: "최근 플레이한 Steam 게임이 아직 없어요.",
                                buttonTitle: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            let items = overview.recentlyPlayed.map { summary in
                LibraryCollectionItem.recentCard(
                    LibraryRecentGameCardViewState(
                        identifier: summary.identifier,
                        title: summary.displayTitle,
                        metadataText: summary.recentPlaytimeText ?? "\(summary.platform) · \(releaseText(for: summary))",
                        ratingText: summary.rating.map { String(format: "%.1f", $0) },
                        coverImageURL: summary.coverImageURL,
                        badgeText: "Steam",
                        actionTitle: playingIdentifiers.contains(summary.identifier) ? nil : "플레이 중으로 추가"
                    )
                )
            }

            return LibrarySectionViewState(
                kind: .recentlyPlayed,
                layoutStyle: .recentCards,
                items: items,
                showsSeeAll: false
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
                            buttonTitle: nil
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
                                buttonTitle: nil
                            )
                        )
                    ],
                    showsSeeAll: false
                )
            }

            let items = overview.playing.map { summary in
                LibraryCollectionItem.row(
                    LibraryGameRowViewState(
                        identifier: summary.identifier,
                        title: summary.displayTitle,
                        subtitleText: "\(summary.genre) · \(releaseText(for: summary))",
                        metadataText: summary.platform,
                        coverImageURL: summary.coverImageURL,
                        ratingText: summary.rating.map { String(format: "%.1f", $0) },
                        trailingAction: nil
                    )
                )
            }

            return LibrarySectionViewState(
                kind: .playing,
                layoutStyle: .list,
                items: items,
                showsSeeAll: false
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
                            buttonTitle: nil
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
                                buttonTitle: nil
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
                            buttonTitle: nil
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
                                buttonTitle: nil
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
                            buttonTitle: nil
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
