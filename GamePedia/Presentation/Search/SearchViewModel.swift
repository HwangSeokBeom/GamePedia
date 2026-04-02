import Foundation

// MARK: - SearchViewModel
//
// The backend /games/search endpoint now handles translation-aware search.
// Korean (or other non-English) queries are translated server-side before
// hitting IGDB, so the client sends the raw user query as-is.

final class SearchViewModel {

    // MARK: State
    private(set) var state: SearchState = SearchState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((SearchState) -> Void)?

    // MARK: Dependencies
    private let apiClient: APIClient

    // MARK: Debounce
    private var searchTask: Task<Void, Never>? = nil
    private let debounceMilliseconds: UInt64 = 400

    // MARK: Init
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
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

        print("[GameSearch] originalQuery=\"\(query)\"")

        do {
            let endpoint = Endpoint.searchGames(
                query: query,
                genre: genre == L10n.Search.Filter.all ? nil : genre
            )
            let response = try await apiClient.request(
                endpoint,
                as: GameResponseEnvelopeDTO<GameListResponseDataDTO>.self
            )
            let games = response.data.games.map { GameMapper.toEntity($0) }
            print("[GameSearch] decodeSuccess resultCount=\(games.count)")
            await MainActor.run {
                self.apply(.setResults(games))
            }
        } catch {
            print("[GameSearch] decodeFailed query=\"\(query)\" error=\(error.localizedDescription)")
            await MainActor.run { self.apply(.setResults([])) }
        }
    }
}
