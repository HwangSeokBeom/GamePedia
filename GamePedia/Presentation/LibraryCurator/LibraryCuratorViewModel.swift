import Combine
import Foundation

final class LibraryCuratorViewModel {
    private enum FetchReason {
        case initialLoad
        case analyzeTapped
        case retryTapped
    }

    private struct RequestKey: Hashable, CustomStringConvertible {
        let mode: String
        let normalizedQuery: String
        let selectedPromptID: String
        let selectedTasteTagIDs: [String]
        let selectedGenreTagIDs: [String]
        let candidateScope: String
        let limit: Int
        let locale: String

        var description: String {
            [
                "mode=\(mode)",
                "query=\(normalizedQuery.isEmpty ? "nil" : normalizedQuery)",
                "prompt=\(selectedPromptID)",
                "taste=\(selectedTasteTagIDs.joined(separator: ","))",
                "genre=\(selectedGenreTagIDs.joined(separator: ","))",
                "scope=\(candidateScope)",
                "limit=\(limit)",
                "locale=\(locale)"
            ].joined(separator: "|")
        }
    }

    private struct CachedCuratorResponse {
        let result: LibraryCuratorResult
        let completedAt: Date
    }

    private(set) var state = LibraryCuratorViewState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((LibraryCuratorViewState) -> Void)?
    var onRouteToGameDetail: ((Int) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    private let fetchLibraryCuratorUseCase: any FetchLibraryCuratorUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private var currentTask: Task<Void, Never>?
    private var currentRequestToken: UUID?
    private var currentRequestKey: RequestKey?
    private var inFlightRequestKeys = Set<RequestKey>()
    private var lastSuccessfulResponses: [RequestKey: CachedCuratorResponse] = [:]
    private var blockedRequestKeysAfterRateLimit = Set<RequestKey>()
    private let successfulResponseCooldown: TimeInterval = 45
    private var didStartInitialLoad = false
    private var didLogInitialLoadSkipped = false
    private var updatingFavoriteGameIds = Set<String>()
    private var gamesById: [String: LibraryCuratorGame] = [:]
    private var seedGamesById: [Int: Game] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchLibraryCuratorUseCase: any FetchLibraryCuratorUseCase = DefaultFetchLibraryCuratorUseCase(),
        toggleFavoriteUseCase: ToggleFavoriteUseCase = ToggleFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        )
    ) {
        self.fetchLibraryCuratorUseCase = fetchLibraryCuratorUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        observeInvalidationEvents()
    }

    deinit {
        currentTask?.cancel()
    }

    func send(_ intent: LibraryCuratorIntent) {
        switch intent {
        case .viewDidLoad:
#if DEBUG
            if !didLogInitialLoadSkipped {
                didLogInitialLoadSkipped = true
                print("[LibraryCurator] requestSkipped reason=initialLoadDisabled")
            }
#endif
        case .queryChanged(let query):
            apply(.setQueryFromUserInput(query))
            if state.errorMessage != nil {
                apply(.setErrorMessage(nil))
            }
        case .modeSelected(let mode):
            let previousPromptID = state.selectedPromptChipID ?? "nil"
            apply(.setPrompt(mode: mode))
#if DEBUG
            print(
                "[LibraryCuratorChip] tap " +
                "id=\(mode.promptChipID) " +
                "title=\(mode.localizedTitle) " +
                "previousSelectedPrompt=\(previousPromptID) " +
                "nextSelectedPrompt=\(state.selectedPromptChipID ?? "nil") " +
                "willRequest=false"
            )
            logChipState()
#endif
        case .tasteTagTapped(let id):
            apply(.toggleTasteTag(id))
#if DEBUG
            print("[LibraryCuratorChip] tap section=taste id=\(id) selected=\(state.selectedTasteTagIDs.contains(id))")
            logChipState()
#endif
        case .genreTagTapped(let id):
            apply(.toggleGenreTag(id))
#if DEBUG
            print("[LibraryCuratorChip] tap section=genre id=\(id) selected=\(state.selectedGenreTagIDs.contains(id))")
            logChipState()
#endif
        case .analyzeTapped:
#if DEBUG
            let requestPreview = makeRequest()
            print(
                "[LibraryCurator] analyzeTapped " +
                "selectedPrompt=\(state.selectedPromptChipID ?? "nil") " +
                "mode=\(requestPreview.mode.rawValue) " +
                "queryExists=\(!(requestPreview.query?.isEmpty ?? true)) " +
                "selectedTagsCount=\(state.selectedTasteTagIDs.count) " +
                "selectedGenreCount=\(state.selectedGenreTagIDs.count)"
            )
#endif
            fetchCuratorResult(reason: .analyzeTapped, forceRefresh: true)
        case .retryTapped:
            fetchCuratorResult(reason: .retryTapped, forceRefresh: true)
        case .gameTapped(let gameId):
            guard let intGameId = Int(gameId.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            if let game = seedGamesById[intGameId] {
                GameDetailSeedStore.shared.store(games: [game], screen: "LibraryCurator.tap")
            }
#if DEBUG
            print("[LibraryCurator] routeToDetail gameId=\(gameId) source=library_curator")
#endif
            onRouteToGameDetail?(intGameId)
        case .favoriteTapped(let gameId):
            toggleFavorite(gameId: gameId)
        }
    }

    func cancelInFlightRequest() {
        currentTask?.cancel()
        currentTask = nil
        currentRequestToken = nil
        if let currentRequestKey {
            inFlightRequestKeys.remove(currentRequestKey)
        }
        currentRequestKey = nil
        if state.isLoading {
            apply(.setLoading(false))
        }
    }

    private func apply(_ mutation: LibraryCuratorMutation) {
        state = LibraryCuratorReducer.reduce(state, mutation)
    }

    private func fetchCuratorResult(reason: FetchReason, forceRefresh: Bool) {
        if reason == .initialLoad {
            guard !didStartInitialLoad else {
#if DEBUG
                print("[LibraryCurator] requestSkipped reason=initialLoadAlreadyStarted")
#endif
                return
            }
            didStartInitialLoad = true
        }

        let request = makeRequest()
        let requestKey = makeRequestKey(for: request)

        if state.isDailyLimitExceeded {
#if DEBUG
            print(
                "[LibraryCurator] analyzeBlocked " +
                "reason=dailyLimitExceeded " +
                "selectedPrompt=\(state.selectedPromptChipID ?? "nil")"
            )
            print("[LibraryCurator] requestSkipped reason=dailyLimitExceeded requestKey=\(requestKey)")
#endif
            apply(.setDailyLimitExceeded(
                message: state.dailyLimitExceededMessage ?? Self.dailyLimitExceededMessage(hasDisplayableResult: state.hasDisplayableResult),
                preserveResults: state.hasDisplayableResult
            ))
            return
        }

        if inFlightRequestKeys.contains(requestKey) {
#if DEBUG
            print("[LibraryCurator] requestSkipped reason=duplicateInFlight requestKey=\(requestKey)")
#endif
            return
        }

        if let cachedResponse = lastSuccessfulResponses[requestKey] {
            let age = Date().timeIntervalSince(cachedResponse.completedAt)
            if age < successfulResponseCooldown {
#if DEBUG
                print(
                    "[LibraryCurator] requestSkipped " +
                    "reason=recentlyCompleted " +
                    "requestKey=\(requestKey) " +
                    "age=\(String(format: "%.1f", age))"
                )
                print(
                    "[LibraryCurator] cachedResponseUsed " +
                    "requestKey=\(requestKey) " +
                    "source=\(cachedResponse.result.source)"
                )
#endif
                displayResult(cachedResponse.result, requestKey: requestKey)
                return
            }
        }

        if blockedRequestKeysAfterRateLimit.contains(requestKey) {
#if DEBUG
            print("[LibraryCurator] requestSkipped reason=rateLimitedRequestKey requestKey=\(requestKey)")
#endif
            apply(.setDailyLimitExceeded(
                message: state.dailyLimitExceededMessage ?? Self.dailyLimitExceededMessage(hasDisplayableResult: state.hasDisplayableResult),
                preserveResults: state.hasDisplayableResult
            ))
            return
        }

        guard state.canAnalyze else {
#if DEBUG
            print("[LibraryCurator] requestSkipped reason=loadingInProgress requestKey=\(requestKey)")
#endif
            return
        }

        currentTask?.cancel()
        apply(.setLoading(true))
        apply(.setErrorMessage(nil))

        let requestToken = UUID()
        currentRequestToken = requestToken
        currentRequestKey = requestKey
        inFlightRequestKeys.insert(requestKey)

#if DEBUG
        print(
            "[LibraryCurator] requestStarted " +
            "requestKey=\(requestKey) " +
            "mode=\(request.mode.rawValue) " +
            "locale=\(request.locale) " +
            "candidateScope=\(request.candidateScope.rawValue) " +
            "limit=\(request.limit) " +
            "queryExists=\(!(request.query?.isEmpty ?? true)) " +
            "selectedPrompt=\(state.selectedPromptChipID ?? "nil") " +
            "selectedTagsCount=\(state.selectedTagsCount)"
        )
#endif

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await fetchLibraryCuratorUseCase.execute(request: request)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard self.currentRequestToken == requestToken else { return }
                    self.currentTask = nil
                    self.currentRequestToken = nil
                    self.currentRequestKey = nil
                    self.inFlightRequestKeys.remove(requestKey)
                    self.lastSuccessfulResponses[requestKey] = CachedCuratorResponse(result: result, completedAt: Date())
                    self.pruneSuccessfulResponseCache()
                    self.displayResult(result, requestKey: requestKey)
#if DEBUG
                    print(
                        "[LibraryCurator] response " +
                        "source=\(result.source) " +
                        "candidateCount=\(result.meta.candidateCount) " +
                        "selectedCount=\(result.meta.selectedCount) " +
                        "requestedLimit=\(request.limit) " +
                        "requestKey=\(requestKey)"
                    )
#endif
                }
            } catch {
                guard !Task.isCancelled else { return }
                let curatorError = LibraryCuratorError.from(error: error)
                await MainActor.run {
                    guard self.currentRequestToken == requestToken else { return }
                    self.currentTask = nil
                    self.currentRequestToken = nil
                    self.inFlightRequestKeys.remove(requestKey)
                    self.currentRequestKey = nil
                    self.apply(.setLoading(false))

                    if curatorError == .unauthorized {
                        self.onAuthenticationRequired?(.profile) { [weak self] in
                            self?.send(.analyzeTapped)
                        }
                        return
                    }

                    if case .dailyLimitExceeded = curatorError {
                        self.blockedRequestKeysAfterRateLimit.insert(requestKey)
                        self.handleDailyLimitExceeded(requestKey: requestKey)
#if DEBUG
                        print(
                            "[LibraryCurator] dailyLimitExceeded " +
                            "code=AI_LIBRARY_CURATOR_DAILY_LIMIT_EXCEEDED " +
                            "message=\(self.state.dailyLimitExceededMessage ?? "")"
                        )
#endif
                        return
                    }

                    self.apply(.setErrorMessage(
                        curatorError.errorDescription ?? L10n.tr("Localizable", "library_curator_error_message")
                    ))
                }
            }
        }
    }

    private func makeRequest() -> LibraryCuratorRequest {
        let query = makeRequestQuery()
        return LibraryCuratorRequest(
            query: query.isEmpty ? nil : query,
            mode: state.selectedMode,
            limit: 5,
            locale: DefaultLanguageProvider.shared.currentLanguageCode,
            candidateScope: .mixed,
            excludedGameIds: []
        )
    }

    private func makeRequestQuery() -> String {
        let selectedTags = selectedTagTitlesForRequest()
        if state.selectedPromptChipID == LibraryCuratorMode.overview.promptChipID {
            return ""
        }

        let baseQuery = state.queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedTags.isEmpty else { return baseQuery }

        let tagContext = "Selected tags: \(selectedTags.joined(separator: ", "))"
        guard !baseQuery.isEmpty else { return tagContext }
        return "\(baseQuery)\n\(tagContext)"
    }

    private func makeLoadedViewState(from result: LibraryCuratorResult) -> LibraryCuratorViewState {
        let gamesById = result.games.reduce(into: [String: LibraryCuratorGame]()) { partialResult, game in
            partialResult[game.gameId] = game
        }
        let sections = result.sections.compactMap { section -> LibraryCuratorSectionViewState? in
            let items = section.items.compactMap { item -> LibraryCuratorItemViewState? in
                guard let game = gamesById[item.gameId] else { return nil }
                return makeItemViewState(item: item, game: game)
            }
            guard !items.isEmpty else { return nil }
            return LibraryCuratorSectionViewState(
                id: section.id,
                title: L10n.tr("Localizable", "library_curator_result_title"),
                description: section.description,
                items: items
            )
        }
        let selectedCount = sections.flatMap(\.items).count
        if selectedCount == 0 {
#if DEBUG
            print("[LibraryCurator] empty reason=\(result.meta.fallbackReason ?? "NO_CANDIDATES")")
#endif
        }

        var viewState = state
        let summaryBody = result.summary.body.nilIfBlankForCurator
        let summaryBullets = result.summary.bullets.map(\.trimmedForCuratorDisplay).filter { !$0.isEmpty }
        let summaryTitle = result.summary.title.nilIfBlankForCurator
            ?? ((summaryBody != nil || !summaryBullets.isEmpty) ? summaryFallbackTitle(for: result.mode) : nil)
        viewState.summaryTitle = summaryTitle
        viewState.summaryBody = summaryBody
        viewState.summaryBullets = summaryBullets
        viewState.tasteTags = makeTasteTags(from: result)
        viewState.sections = sections
        viewState.isFallback = result.isFallback
        viewState.fallbackMessage = result.isFallback ? L10n.tr("Localizable", "library_curator_fallback_message") : nil
        viewState.emptyMessage = selectedCount == 0 ? L10n.tr("Localizable", "library_curator_empty_message") : nil
        viewState.generatedAtText = makeGeneratedAtText(result.meta.generatedAt)
        return viewState
    }

    private func makeItemViewState(
        item: LibraryCuratorItem,
        game: LibraryCuratorGame
    ) -> LibraryCuratorItemViewState {
        let localizedGenres = RecommendationTagLocalizer.localizedGenres(
            for: game.genres,
            screen: "LibraryCurator.genre"
        )
        let genreText = localizedGenres.prefix(2).joined(separator: ", ")
        let platformText = game.platforms.prefix(2).joined(separator: ", ")
        let subtitle: String
        switch (genreText.isEmpty, platformText.isEmpty) {
        case (false, false):
            subtitle = "\(genreText) · \(platformText)"
        case (false, true):
            subtitle = genreText
        case (true, false):
            subtitle = platformText
        case (true, true):
            subtitle = L10n.Home.List.recommendation
        }

        let ratingText = game.rating.map {
            GameRatingDisplayFormatter.makeDisplay(
                userRating: $0,
                aggregatedRating: nil,
                totalRating: nil
            ).displayText ?? "—"
        } ?? "—"
        let displayTags = RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: item.matchTags,
            genres: game.genres,
            maxCount: 4,
            screen: "LibraryCurator"
        )

        return LibraryCuratorItemViewState(
            gameId: game.gameId,
            title: game.title,
            coverUrl: game.coverURL,
            subtitle: subtitle,
            ratingText: ratingText,
            reason: item.reason,
            displayTags: displayTags,
            confidenceText: L10n.tr("Localizable", "library_curator_confidence_format", Int((item.confidence * 100).rounded())),
            isFavorite: game.isFavorite,
            playtimeText: makePlaytimeText(game.playtimeMinutes),
            userRatingText: makeUserRatingText(game.userRating)
        )
    }

    private func makeTasteTags(from result: LibraryCuratorResult) -> [String] {
        let tags = result.tasteProfile.topGenres
            + result.tasteProfile.topThemes
            + [result.tasteProfile.preferredSession]
            + result.tasteProfile.playStyleTags
            + [result.tasteProfile.ratingStyle].compactMap { $0 }
        return RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: tags,
            maxCount: 8,
            screen: "LibraryCurator.taste"
        )
    }

    private func selectedTagTitlesForRequest() -> [String] {
        let tasteTagTitles = state.tasteTags.filter {
            state.selectedTasteTagIDs.contains(Self.tagID(for: $0, section: "taste"))
        }
        let genreTagTitles = state.sections
            .flatMap(\.items)
            .flatMap(\.displayTags)
            .filter {
                state.selectedGenreTagIDs.contains(Self.tagID(for: $0, section: "genre"))
            }
        var seen = Set<String>()
        return (tasteTagTitles + genreTagTitles).filter { seen.insert($0).inserted }
    }

    static func tagID(for title: String, section: String) -> String {
        let normalizedTitle = RecommendationTagLocalizer.normalizedKey(for: title)
        return "\(section):\(normalizedTitle.isEmpty ? title.lowercased() : normalizedTitle)"
    }

    private func makeRequestKey(for request: LibraryCuratorRequest) -> RequestKey {
        let includesTagFilters = state.selectedPromptChipID != LibraryCuratorMode.overview.promptChipID
        return RequestKey(
            mode: request.mode.rawValue,
            normalizedQuery: normalizedRequestQuery(request.query),
            selectedPromptID: state.selectedPromptChipID ?? "manual",
            selectedTasteTagIDs: includesTagFilters ? state.selectedTasteTagIDs.sorted() : [],
            selectedGenreTagIDs: includesTagFilters ? state.selectedGenreTagIDs.sorted() : [],
            candidateScope: request.candidateScope.rawValue,
            limit: request.limit,
            locale: request.locale
        )
    }

    private func normalizedRequestQuery(_ query: String?) -> String {
        guard let query else { return "" }
        return query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()
    }

#if DEBUG
    private func logChipState() {
        print(
            "[LibraryCuratorChip] state " +
            "selectedPrompt=\(state.selectedPromptChipID ?? "nil") " +
            "selectedTasteCount=\(state.selectedTasteTagIDs.count) " +
            "selectedGenreCount=\(state.selectedGenreTagIDs.count)"
        )
    }
#endif

    private func makeSeedGames(from result: LibraryCuratorResult) -> [Game] {
        let reasonByGameId = result.sections
            .flatMap(\.items)
            .reduce(into: [String: String]()) { partialResult, item in
                partialResult[item.gameId] = item.reason
            }
        return result.games.compactMap {
            LibraryCuratorMapper.toGame($0, reason: reasonByGameId[$0.gameId])
        }
    }

    private static func dailyLimitExceededMessage(hasDisplayableResult: Bool) -> String {
        L10n.tr(
            "Localizable",
            hasDisplayableResult
                ? "library_curator_daily_limit_message"
                : "library_curator_daily_limit_message_no_result"
        )
    }

    private func displayResult(_ result: LibraryCuratorResult, requestKey: RequestKey) {
        let viewState = makeLoadedViewState(from: result)
        let seedGames = makeSeedGames(from: result)

        gamesById = result.games.reduce(into: [:]) { partialResult, game in
            partialResult[game.gameId] = game
        }
        seedGamesById = seedGames.reduce(into: [:]) { partialResult, game in
            partialResult[game.id] = game
        }
        GameDetailSeedStore.shared.store(games: seedGames, screen: "LibraryCurator.result")
        apply(.setLoaded(
            result: result,
            summaryTitle: viewState.summaryTitle,
            summaryBody: viewState.summaryBody,
            summaryBullets: viewState.summaryBullets,
            tasteTags: viewState.tasteTags,
            sections: viewState.sections,
            isFallback: viewState.isFallback,
            fallbackMessage: viewState.fallbackMessage,
            emptyMessage: viewState.emptyMessage,
            generatedAtText: viewState.generatedAtText
        ))
        apply(.setLoading(false))

#if DEBUG
        if result.isFallback {
            print(
                "[LibraryCurator] fallbackDisplayed " +
                "reason=\(result.meta.fallbackReason ?? "nil") " +
                "requestKey=\(requestKey)"
            )
        }
#endif
    }

    private func handleDailyLimitExceeded(requestKey: RequestKey) {
        if !state.hasDisplayableResult, let lastSuccessfulResult = state.lastSuccessfulResult {
            displayResult(lastSuccessfulResult, requestKey: requestKey)
        }

        let hasDisplayableResult = state.hasDisplayableResult
        apply(.setDailyLimitExceeded(
            message: Self.dailyLimitExceededMessage(hasDisplayableResult: hasDisplayableResult),
            preserveResults: hasDisplayableResult
        ))
    }

    private func pruneSuccessfulResponseCache() {
        let now = Date()
        lastSuccessfulResponses = lastSuccessfulResponses.filter {
            now.timeIntervalSince($0.value.completedAt) < 300
        }
    }

    private func toggleFavorite(gameId: String) {
        guard !state.isLoading else { return }
        guard !updatingFavoriteGameIds.contains(gameId) else { return }
        let isCurrentlyFavorite = state.sections.flatMap(\.items).first { $0.gameId == gameId }?.isFavorite ?? false
        updatingFavoriteGameIds.insert(gameId)
        apply(.setFavorite(gameId: gameId, isFavorite: !isCurrentlyFavorite))
        apply(.setFavoriteUpdating(gameId: gameId, isUpdating: true))

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await toggleFavoriteUseCase.execute(
                    gameId: gameId,
                    isCurrentlyFavorite: isCurrentlyFavorite
                )
                await MainActor.run {
                    self.updatingFavoriteGameIds.remove(gameId)
                    self.apply(.setFavorite(gameId: gameId, isFavorite: result.isFavorite))
                    self.apply(.setFavoriteUpdating(gameId: gameId, isUpdating: false))
                    NotificationCenter.default.post(
                        name: .favoriteDidChange,
                        object: nil,
                        userInfo: [
                            FavoriteChangeUserInfoKey.gameId: result.gameId,
                            FavoriteChangeUserInfoKey.isFavorite: result.isFavorite,
                            FavoriteChangeUserInfoKey.action: result.isFavorite
                                ? FavoriteChangeAction.added.rawValue
                                : FavoriteChangeAction.removed.rawValue
                        ]
                    )
                }
            } catch {
                let favoriteError = FavoriteError.from(error: error)
                await MainActor.run {
                    self.updatingFavoriteGameIds.remove(gameId)
                    self.apply(.setFavorite(gameId: gameId, isFavorite: isCurrentlyFavorite))
                    self.apply(.setFavoriteUpdating(gameId: gameId, isUpdating: false))

                    if favoriteError == .unauthorized {
                        self.onAuthenticationRequired?(.profile) { [weak self] in
                            self?.send(.favoriteTapped(gameId))
                        }
                        return
                    }

                    self.apply(.setErrorMessage(
                        favoriteError.errorDescription ?? L10n.tr("Localizable", "favorite.error.updateFailed")
                    ))
                }
            }
        }
    }

    private func observeInvalidationEvents() {
        [
            Notification.Name.favoriteDidChange,
            .reviewDidChange,
            .libraryDidChange,
            .steamLinkDidComplete,
            .steamLinkStateDidChange
        ].forEach { name in
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self, self.state.hasLoadedOnce, !self.state.sections.isEmpty else { return }
                    self.apply(.setStale(true))
                }
                .store(in: &cancellables)
        }
    }

    private func makePlaytimeText(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let hours = Double(minutes) / 60.0
        return L10n.tr("Localizable", "library_curator_playtime_format", LocalizedNumberFormatter.oneFraction(hours))
    }

    private func makeUserRatingText(_ rating: Double?) -> String? {
        guard let rating, rating.isFinite else { return nil }
        return L10n.tr("Localizable", "library_curator_user_rating_format", LocalizedNumberFormatter.oneFraction(rating))
    }

    private func summaryFallbackTitle(for mode: LibraryCuratorMode) -> String {
        switch mode {
        case .overview:
            return "라이브러리 전체 분석"
        case .today:
            return "오늘 이어가기 좋은 게임"
        case .rediscover:
            return "다시 꺼내기 좋은 게임"
        case .shortSession:
            return "짧게 즐기기 좋은 게임"
        case .reviewInsight:
            return "리뷰 성향 분석"
        }
    }

    private func makeGeneratedAtText(_ generatedAt: String) -> String? {
        let trimmedValue = generatedAt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private extension Optional where Wrapped == String {
    var nilIfBlankForCurator: String? {
        guard let value = self?.trimmedForCuratorDisplay, !value.isEmpty else { return nil }
        return value
    }
}

private extension String {
    var nilIfBlankForCurator: String? {
        let value = trimmedForCuratorDisplay
        return value.isEmpty ? nil : value
    }

    var trimmedForCuratorDisplay: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
