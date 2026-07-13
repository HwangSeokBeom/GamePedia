import Foundation

// MARK: - SearchViewModel
//
// The backend /games/search endpoint now handles translation-aware search.
// Korean (or other non-English) queries are translated server-side before
// hitting IGDB, so the client sends the raw user query as-is.

@MainActor
final class SearchViewModel {

    typealias SearchLoader = (_ query: String, _ genre: String?) async throws -> [Game]

    // MARK: State
    private(set) var state: SearchState = SearchState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((SearchState) -> Void)?

    // MARK: Dependencies
    private let loadGames: SearchLoader

    // MARK: Debounce
    private var searchTask: Task<Void, Never>? = nil
    private let debounceNanoseconds: UInt64
    private var activeSearchID: UUID?

    // MARK: Init
    init(
        apiClient: APIClient = .shared,
        debounceNanoseconds: UInt64 = 400_000_000,
        loadGames: SearchLoader? = nil
    ) {
        self.debounceNanoseconds = debounceNanoseconds
        self.loadGames = loadGames ?? { query, genre in
            let endpoint = Endpoint.searchGames(query: query, genre: genre)
            let response = try await apiClient.request(
                endpoint,
                as: GameResponseEnvelopeDTO<GameListResponseDataDTO>.self
            )
            return response.data.games.map { GameMapper.toEntity($0) }
        }
    }

    deinit {
        searchTask?.cancel()
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
            invalidateSearch()
        case .genreSelected(let genre):
            apply(.setGenre(genre))
            // The canonical search endpoint does not accept a genre parameter yet.
            // SearchViewController filters the complete result set locally, so a
            // chip change must not issue an identical network request.
        case .retryTapped:
            scheduleSearch(query: state.query, genre: state.selectedGenre, debounce: false)
        case .didTapGame:
            break   // handled by ViewController
        }
    }

    func cancelInFlightRequest() {
        invalidateSearch()
    }

    // MARK: - Private

    private func apply(_ mutation: SearchMutation) {
        state = SearchReducer.reduce(state, mutation)
    }

    private func scheduleSearch(query: String, genre: SearchGenre, debounce: Bool = true) {
        searchTask?.cancel()
        let normalizedQuery = SearchQueryPolicy.normalizedQuery(from: query)
        guard !normalizedQuery.isEmpty else {
            invalidateSearch()
            return
        }

        let searchID = UUID()
        activeSearchID = searchID
        apply(.prepareSearch)

        searchTask = Task { [weak self] in
            guard let self else { return }
            if debounce {
                do {
                    try await Task.sleep(nanoseconds: debounceNanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await performSearch(query: normalizedQuery, genre: genre, searchID: searchID)
        }
    }

    private func performSearch(query: String, genre: SearchGenre, searchID: UUID) async {
        guard activeSearchID == searchID else { return }
        apply(.setSearching(true))

        print("[GameSearch] request queryLength=\(query.count)")

        do {
            let games = try await loadGames(
                query,
                genre == .all ? nil : genre.rawValue
            )
            print("[GameSearch] decodeSuccess resultCount=\(games.count)")
            guard activeSearchID == searchID else { return }
            activeSearchID = nil
            apply(.setResults(games))
        } catch {
            guard !Task.isCancelled else { return }
            print("[GameSearch] requestFailed queryLength=\(query.count) errorType=\(String(describing: type(of: error)))")
            guard activeSearchID == searchID else { return }
            activeSearchID = nil
            apply(.setError(L10n.Search.Error.loadFailed))
        }
    }

    private func invalidateSearch() {
        searchTask?.cancel()
        searchTask = nil
        activeSearchID = nil
        apply(.clearResults)
    }
}
