import Foundation

// MARK: - SearchViewModel

final class SearchViewModel {

    // MARK: State
    private(set) var state: SearchState = SearchState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((SearchState) -> Void)?

    // MARK: Dependencies
    private let apiClient: APIClient
    private let translateTextUseCase: TranslateTextUseCase

    // MARK: Debounce
    private var searchTask: Task<Void, Never>? = nil
    private let debounceMilliseconds: UInt64 = 400

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

    func send(_ intent: SearchIntent) {
        switch intent {
        case .viewDidLoad:
            break
        case .queryChanged(let query):
            apply(.setQuery(query))
            scheduleSearch(query: query, genre: state.selectedGenre)
        case .queryCleared:
            apply(.setQuery(""))
            apply(.clearResults)
            searchTask?.cancel()
        case .genreSelected(let genre):
            apply(.setGenre(genre))
            if !state.query.isEmpty {
                scheduleSearch(query: state.query, genre: genre)
            }
        case .didTapGame:
            break   // handled by ViewController
        }
    }

    // MARK: - Private

    private func apply(_ mutation: SearchMutation) {
        state = SearchReducer.reduce(state, mutation)
    }

    private func scheduleSearch(query: String, genre: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            apply(.clearResults)
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: debounceMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: query, genre: genre)
        }
    }

    private func performSearch(query: String, genre: String) async {
        await MainActor.run { apply(.setSearching(true)) }

        do {
            let endpoint = Endpoint.searchGames(query: query, genre: genre == "전체" ? nil : genre)
            let response = try await apiClient.request(
                endpoint,
                as: GameResponseEnvelopeDTO<GameListResponseDataDTO>.self
            )
            let games = response.data.games.map { GameMapper.toEntity($0) }
            print("[GameSearch] query=\(query) resultCount=\(games.count)")
            let translatedGames = await translateGames(games, context: "Search")
            await MainActor.run {
                self.apply(.setResults(translatedGames))
            }
        } catch {
            print("[GameSearch] failed query=\(query) error=\(error.localizedDescription)")
            await MainActor.run { self.apply(.setResults([])) }
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

        let summaryItems = games.compactMap { game -> TranslationRequestItem? in
            guard game.translatedSummary == nil, let summary = game.summary else { return nil }
            return TranslationRequestItem(
                identifier: String(game.id),
                field: "summary",
                text: summary
            )
        }

        async let translatedTitles = translateTextUseCase.execute(
            items: titleItems,
            context: "\(context).title",
            sourceLanguage: "en"
        )
        async let translatedSummaries = translateTextUseCase.execute(
            items: summaryItems,
            context: "\(context).summary",
            sourceLanguage: "en"
        )

        let titleResults = await translatedTitles
        let summaryResults = await translatedSummaries
        let titleMap = Dictionary(uniqueKeysWithValues: titleResults.map { ($0.identifier, $0.translatedText) })
        let summaryMap = Dictionary(uniqueKeysWithValues: summaryResults.map { ($0.identifier, $0.translatedText) })

        return games.map { game in
            game.replacingTranslated(
                translatedTitle: titleMap[String(game.id)],
                translatedSummary: summaryMap[String(game.id)]
            )
        }
    }
}
