import Combine
import Foundation

final class AIRecommendationViewModel {
    private(set) var state: AIRecommendationState = AIRecommendationState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((AIRecommendationState) -> Void)?
    var onRouteToGameDetail: ((Int) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    private let fetchAIRecommendationsUseCase: any FetchAIRecommendationsUseCase
    private let fetchMyFavoritesUseCase: FetchMyFavoritesUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private var currentRecommendationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var recommendationGamesById: [Int: Game] = [:]
    private var updatingFavoriteGameIds = Set<Int>()
    private var currentRecommendationToken: UUID?

    init(
        fetchAIRecommendationsUseCase: any FetchAIRecommendationsUseCase = DefaultFetchAIRecommendationsUseCase(),
        fetchMyFavoritesUseCase: FetchMyFavoritesUseCase = FetchMyFavoritesUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        toggleFavoriteUseCase: ToggleFavoriteUseCase = ToggleFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        )
    ) {
        self.fetchAIRecommendationsUseCase = fetchAIRecommendationsUseCase
        self.fetchMyFavoritesUseCase = fetchMyFavoritesUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        observeFavoriteChanges()
    }

    deinit {
        currentRecommendationTask?.cancel()
    }

    func send(_ intent: AIRecommendationIntent) {
        switch intent {
        case .viewDidLoad:
            apply(.setExamples([
                "퇴근 후 힐링",
                "친구랑 같이",
                "스토리 좋은 RPG",
                "짧게 즐기는 게임"
            ]))
            loadFavoriteStatus()
        case .queryChanged(let query):
            if state.isLoading, query != state.query {
                cancelInFlightRequest()
            }
            apply(.setQuery(query))
            if state.errorMessage != nil {
                apply(.setErrorMessage(nil))
            }
        case .exampleChipTapped(let example):
            apply(.setQuery(example))
            apply(.setErrorMessage(nil))
        case .recommendButtonTapped:
            fetchRecommendations()
        case .gameTapped(let gameId):
            if let game = recommendationGamesById[gameId] {
                GameDetailSeedStore.shared.store(games: [game], screen: "AIRecommendation.tap")
            }
            onRouteToGameDetail?(gameId)
        case .favoriteTapped(let gameId):
            toggleFavorite(gameId: gameId)
        case .retryTapped:
            fetchRecommendations()
        }
    }

    private func apply(_ mutation: AIRecommendationMutation) {
        state = AIRecommendationReducer.reduce(state, mutation)
    }

    private func fetchRecommendations() {
        guard state.isRecommendButtonEnabled else { return }

        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return }
        currentRecommendationTask?.cancel()
        apply(.setLoading(true))
        apply(.setErrorMessage(nil))
        apply(.setHasRequestedRecommendations(true))
        let recommendationToken = UUID()
        currentRecommendationToken = recommendationToken

        currentRecommendationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await fetchAIRecommendationsUseCase.execute(query: query)
                let favoriteGameIds = await loadFavoriteGameIds()
                guard !Task.isCancelled else { return }
                let items = result.items.map { recommendation in
                    makeItemViewState(
                        from: recommendation,
                        isFavorite: favoriteGameIds.contains(recommendation.gameId)
                    )
                }
                let games = result.items.map(AIRecommendationMapper.toGame)

                await MainActor.run {
                    guard self.currentRecommendationToken == recommendationToken else { return }
                    self.currentRecommendationTask = nil
                    self.currentRecommendationToken = nil
                    self.recommendationGamesById = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
                    GameDetailSeedStore.shared.store(games: games, screen: "AIRecommendation.result")
                    self.apply(.setRecommendations(items))
                    self.apply(.setDisclaimer(result.disclaimer))
                    self.apply(.setLoading(false))
                }
            } catch {
                guard !Task.isCancelled else { return }
                let recommendationError = AIRecommendationError.from(error: error)
                await MainActor.run {
                    guard self.currentRecommendationToken == recommendationToken else { return }
                    self.currentRecommendationTask = nil
                    self.currentRecommendationToken = nil
                    self.apply(.setLoading(false))

                    if recommendationError == .unauthorized {
                        self.onAuthenticationRequired?(.profile) { [weak self] in
                            self?.send(.recommendButtonTapped)
                        }
                        return
                    }

                    self.apply(.setErrorMessage(
                        recommendationError.errorDescription
                            ?? "추천을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
                    ))
                }
            }
        }
    }

    private func loadFavoriteStatus() {
        Task { [weak self] in
            guard let self else { return }
            let favoriteGameIds = await loadFavoriteGameIds()
            await MainActor.run {
                favoriteGameIds.forEach {
                    self.apply(.setFavorite(gameId: $0, isFavorite: true))
                }
            }
        }
    }

    private func loadFavoriteGameIds() async -> Set<Int> {
        do {
            let favorites = try await fetchMyFavoritesUseCase.execute(sort: .latest)
            return Set(favorites.map(\.gameId))
        } catch {
            return []
        }
    }

    private func toggleFavorite(gameId: Int) {
        guard !state.isLoading else { return }
        guard !updatingFavoriteGameIds.contains(gameId) else { return }

        let isCurrentlyFavorite = state.recommendations.first { $0.gameId == gameId }?.isFavorite ?? false
        updatingFavoriteGameIds.insert(gameId)
        apply(.setFavorite(gameId: gameId, isFavorite: !isCurrentlyFavorite))
        apply(.setFavoriteUpdating(gameId: gameId, isUpdating: true))

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await toggleFavoriteUseCase.execute(
                    gameId: String(gameId),
                    isCurrentlyFavorite: isCurrentlyFavorite
                )

                await MainActor.run {
                    self.updatingFavoriteGameIds.remove(gameId)
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
                            self?.send(.favoriteTapped(gameId: gameId))
                        }
                        return
                    }

                    self.apply(.setErrorMessage(
                        favoriteError.errorDescription
                            ?? L10n.tr("Localizable", "favorite.error.updateFailed")
                    ))
                }
            }
        }
    }

    private func observeFavoriteChanges() {
        NotificationCenter.default.publisher(for: .favoriteDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let gameId = notification.userInfo?[FavoriteChangeUserInfoKey.gameId] as? Int,
                      let isFavorite = notification.userInfo?[FavoriteChangeUserInfoKey.isFavorite] as? Bool else {
                    return
                }

                self.apply(.setFavorite(gameId: gameId, isFavorite: isFavorite))
            }
            .store(in: &cancellables)
    }

    private func makeItemViewState(
        from recommendation: AIRecommendation,
        isFavorite: Bool
    ) -> AIRecommendationItemViewState {
        let ratingText: String
        if let rating = recommendation.rating {
            ratingText = GameRatingDisplayFormatter.makeDisplay(
                userRating: rating,
                aggregatedRating: nil,
                totalRating: nil
            ).displayText ?? "—"
        } else {
            ratingText = "—"
        }

        let displayTags = TagLocalizer.localizedTags(
            for: recommendation.matchTags,
            screen: "AIRecommendation"
        )

#if DEBUG
        if !recommendation.matchTags.isEmpty || !displayTags.isEmpty {
            print(
                "[AIRecommendationTags] localized gameId=\(recommendation.gameId) rawTags=[\(recommendation.matchTags.joined(separator: ","))] displayTags=[\(displayTags.joined(separator: ","))]"
            )
        }
#endif

        return AIRecommendationItemViewState(
            gameId: recommendation.gameId,
            title: recommendation.title,
            coverURL: recommendation.coverURL,
            platforms: recommendation.platforms,
            genres: recommendation.genres,
            ratingText: ratingText,
            reason: recommendation.reason,
            matchTags: recommendation.matchTags,
            displayTags: displayTags,
            confidence: recommendation.confidence,
            isFavorite: isFavorite,
            isFavoriteUpdating: false
        )
    }

    func cancelInFlightRequest() {
        currentRecommendationTask?.cancel()
        currentRecommendationTask = nil
        currentRecommendationToken = nil
        if state.isLoading {
            apply(.setLoading(false))
        }
    }
}
