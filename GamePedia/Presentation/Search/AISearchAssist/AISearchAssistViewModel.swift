import Foundation

final class AISearchAssistViewModel {
    private(set) var state: AISearchAssistState = AISearchAssistState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((AISearchAssistState) -> Void)?
    var onRouteToGameDetail: ((Int) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    private let fetchAISearchAssistUseCase: any FetchAISearchAssistUseCase
    private var currentTask: Task<Void, Never>?
    private var gamesById: [Int: Game] = [:]
    private var lastNavigationRequest: (gameId: Int, date: Date)?
    private let navigationDebounceInterval: TimeInterval = 0.5

    init(fetchAISearchAssistUseCase: any FetchAISearchAssistUseCase = DefaultFetchAISearchAssistUseCase()) {
        self.fetchAISearchAssistUseCase = fetchAISearchAssistUseCase
    }

    deinit {
        cancelInFlightRequest()
    }

    func send(_ intent: AISearchAssistIntent) {
        switch intent {
        case .viewDidLoad:
            break
        case .queryChanged(let query):
            if state.isLoading, query != state.query {
                cancelInFlightRequest()
            }
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQuery.isEmpty {
                apply(.clearResult)
            } else {
                apply(.setQuery(query))
            }
        case .searchSubmitted:
            guard state.query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 else { return }
            fetchAssist(force: false)
        case .aiAssistTapped:
            fetchAssist(force: false)
        case .suggestedQueryTapped(let query):
            apply(.setQuery(query))
            fetchAssist(force: true)
        case .retryTapped:
            fetchAssist(force: true)
        case .itemTapped(let gameId):
            guard shouldRouteToGameDetail(gameId: gameId) else { return }
#if DEBUG
            print("[AISearchAssist] itemTapped gameId=\(gameId)")
#endif
            if let game = gamesById[gameId] {
                GameDetailSeedStore.shared.store(games: [game], screen: "AISearchAssist.tap")
            }
            onRouteToGameDetail?(gameId)
        }
    }

    func cancelInFlightRequest() {
        currentTask?.cancel()
        currentTask = nil
        if state.isLoading {
            apply(.setLoading(false))
            apply(.setRequestToken(nil))
        }
    }

    private func apply(_ mutation: AISearchAssistMutation) {
        state = AISearchAssistReducer.reduce(state, mutation)
    }

    private func fetchAssist(force: Bool) {
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard state.canRequestAISearch, query.count >= 2 else { return }

        let platforms: [String] = []
        let genres: [String] = []
        let signature = makeSignature(query: query, platforms: platforms, genres: genres)
        guard force || signature != state.lastRequestedSignature || state.status != .loaded else { return }
        guard !state.isLoading else { return }

        currentTask?.cancel()
        let token = UUID()
        apply(.setRequestToken(token))
        apply(.setLoading(true))

#if DEBUG
        print("[AISearchAssist] request query=\(query) limit=10")
#endif

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await fetchAISearchAssistUseCase.execute(
                    query: query,
                    platforms: platforms,
                    genres: genres
                )
                guard !Task.isCancelled else { return }
                let items = result.items.map(makeItemViewState)
                let games = result.items.map(AISearchAssistMapper.toGame)
                let intentChips = makeIntentChips(from: result.intent)

                await MainActor.run {
                    guard self.state.currentRequestToken == token else { return }
                    self.currentTask = nil
                    self.apply(.setRequestToken(nil))
                    self.gamesById = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
                    GameDetailSeedStore.shared.store(games: games, screen: "AISearchAssist.result")
                    if items.isEmpty {
                        self.apply(.setEmpty(message: "조건에 맞는 게임을 찾지 못했어요. 검색어를 조금 바꿔보세요.", requestSignature: signature))
                    } else {
                        self.apply(.setLoaded(
                            items: items,
                            suggestedQueries: result.suggestedQueries,
                            intentChips: intentChips,
                            normalizedQuery: result.normalizedQuery.isEmpty ? result.originalQuery : result.normalizedQuery,
                            fallbackUsed: result.fallbackUsed,
                            disclaimer: result.disclaimer,
                            requestSignature: signature
                        ))
                    }
#if DEBUG
                    print("[AISearchAssist] response itemCount=\(items.count) fallbackUsed=\(result.fallbackUsed)")
#endif
                }
            } catch {
                guard !Task.isCancelled else { return }
                let searchAssistError = AISearchAssistError.from(error: error)
                await MainActor.run {
                    guard self.state.currentRequestToken == token else { return }
                    self.currentTask = nil
                    self.apply(.setRequestToken(nil))
#if DEBUG
                    print("[AISearchAssist] error code=\(searchAssistError.serverCodeForLog)")
#endif
                    switch searchAssistError {
                    case .dailyLimitExceeded:
                        self.apply(.setDailyLimitExceeded(searchAssistError.errorDescription ?? "오늘 사용할 수 있는 AI 검색 보조 횟수를 모두 사용했어요."))
                    case .unauthorized:
                        self.apply(.setUnauthorized("로그인이 필요해요."))
                        self.onAuthenticationRequired?(.profile) { [weak self] in
                            self?.send(.retryTapped)
                        }
                    case .candidateNotFound:
                        self.apply(.setEmpty(
                            message: searchAssistError.errorDescription,
                            requestSignature: signature
                        ))
                    default:
                        self.apply(.setError(
                            searchAssistError.errorDescription
                                ?? "AI 검색 보조를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
                        ))
                    }
                }
            }
        }
    }

    private func makeSignature(query: String, platforms: [String], genres: [String]) -> String {
        ([query] + platforms.sorted() + genres.sorted()).joined(separator: "|")
    }

    private func shouldRouteToGameDetail(gameId: Int) -> Bool {
        let now = Date()
        if let lastNavigationRequest,
           lastNavigationRequest.gameId == gameId,
           now.timeIntervalSince(lastNavigationRequest.date) < navigationDebounceInterval {
            return false
        }

        lastNavigationRequest = (gameId, now)
        return true
    }

    private func makeItemViewState(from item: AISearchAssistItem) -> AISearchAssistItemViewState {
        let ratingText: String
        if let rating = item.rating {
            ratingText = GameRatingDisplayFormatter.makeDisplay(
                userRating: rating,
                aggregatedRating: nil,
                totalRating: nil
            ).displayText ?? "—"
        } else {
            ratingText = "—"
        }

        let displayTags = TagLocalizer.localizedTags(
            for: item.matchTags,
            screen: "AISearchAssist"
        )

#if DEBUG
        if !item.matchTags.isEmpty || !displayTags.isEmpty {
            print(
                "[AISearchAssistTags] localized gameId=\(item.gameId) rawTags=[\(item.matchTags.joined(separator: ","))] displayTags=[\(displayTags.joined(separator: ","))]"
            )
        }
#endif

        return AISearchAssistItemViewState(
            gameId: item.gameId,
            title: item.title,
            coverURL: item.coverURL,
            platforms: item.platforms,
            genres: item.genres,
            ratingText: ratingText,
            matchReason: item.matchReason,
            matchTags: item.matchTags,
            displayTags: displayTags,
            confidence: item.confidence
        )
    }

    private func makeIntentChips(from intent: AISearchAssistIntentSummary?) -> [String] {
        guard let intent else { return [] }
        let rawChips = (
            intent.mood
            + [intent.sessionLength, intent.playMode, intent.difficulty].compactMap { $0 }
            + intent.platforms
            + intent.genres
            + intent.keywords
        )
        return TagLocalizer.localizedTags(for: rawChips, screen: "AISearchAssist")
    }
}
