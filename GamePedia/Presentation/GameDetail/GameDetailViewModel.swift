import Foundation

// MARK: - GameDetailViewModel

final class GameDetailViewModel {

    // MARK: State
    private(set) var state: GameDetailState = GameDetailState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((GameDetailState) -> Void)?

    // MARK: Navigation Events — handled by ViewController
    var onWriteReview: ((GameDetail) -> Void)?
    var onShare: ((GameDetail) -> Void)?

    // MARK: Dependencies
    private let apiClient: APIClient
    private let translateTextUseCase: TranslateTextUseCase

    // MARK: Init
    init(
        apiClient: APIClient = .shared,
        translateTextUseCase: TranslateTextUseCase? = nil
    ) {
        self.apiClient = apiClient
        self.translateTextUseCase = translateTextUseCase ?? DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        )
    }

    // MARK: - Intent Processing

    func send(_ intent: GameDetailIntent) {
        switch intent {
        case .viewDidLoad(let id):
            loadDetail(gameId: id)
        case .didTapHaveIt:
            apply(.setOwned(!state.isOwned))
        case .didTapWriteReview:
            guard let game = state.game else { return }
            onWriteReview?(game)
        case .didTapShare:
            guard let game = state.game else { return }
            onShare?(game)
        case .didTapSeeAllReviews:
            break
        }
    }

    // MARK: - Private

    private func apply(_ mutation: GameDetailMutation) {
        state = GameDetailReducer.reduce(state, mutation)
    }

    private func loadDetail(gameId: Int) {
        apply(.setLoading(true))

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchGame(id: gameId) }
                group.addTask { await self.fetchReviews(gameId: gameId) }
            }
        }
    }

    private func fetchGame(id: Int) async {
        do {
            // IGDB returns an array even for single-item queries
            let dtos = try await apiClient.request(.gameDetail(id: id), as: [IGDBGameDetailDTO].self)
            guard let dto = dtos.first else {
                await MainActor.run { self.apply(.setError("게임 정보를 찾을 수 없습니다.")) }
                return
            }
            let entity = IGDBGameMapper.toDetailEntity(dto)
            let translatedEntity = await translateGame(entity)
            await MainActor.run {
                self.apply(.setGame(translatedEntity))
            }
        } catch {
            await MainActor.run { self.apply(.setError(error.localizedDescription)) }
        }
    }

    private func fetchReviews(gameId: Int) async {
        do {
            let response = try await apiClient.request(
                .gameReviews(gameId: gameId, limit: 5),
                as: ReviewListResponseDTO.self
            )
            let reviews = response.reviews.map { ReviewMapper.toEntity($0) }
            await MainActor.run {
                self.apply(.setReviews(reviews))
            }
        } catch {
            // Reviews failing silently — detail still shows
        }
    }

    private func translateGame(_ game: GameDetail) async -> GameDetail {
        let normalizedSummary = game.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoryline = game.storyline.trimmingCharacters(in: .whitespacesAndNewlines)
        let sharesSummaryText = normalizedSummary == normalizedStoryline

        let items = [
            game.translatedTitle == nil
                ? TranslationRequestItem(identifier: String(game.id), field: "title", text: game.title)
                : nil,
            !normalizedSummary.isEmpty
                ? TranslationRequestItem(identifier: String(game.id), field: "summary", text: game.summary)
                : nil,
            !normalizedStoryline.isEmpty && !sharesSummaryText
                ? TranslationRequestItem(identifier: String(game.id), field: "storyline", text: game.storyline)
                : nil
        ].compactMap { $0 }

        guard !items.isEmpty else { return game }

        let results = await translateTextUseCase.execute(
            items: items,
            context: "GameDetail",
            sourceLanguage: "en"
        )
        let translatedValues = Dictionary(uniqueKeysWithValues: results.map { ($0.field, $0.translatedText) })
        let translatedSummary = translatedValues["summary"]
        let translatedStoryline = translatedValues["storyline"] ?? (sharesSummaryText ? translatedSummary : nil)

        return game.replacingTranslated(
            translatedTitle: translatedValues["title"],
            translatedSummary: translatedSummary,
            translatedStoryline: translatedStoryline
        )
    }
}
