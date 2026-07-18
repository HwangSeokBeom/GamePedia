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
    // Latest-request-wins identity: the inline `activeSearchID` UUID this
    // view model pioneered, now provided by the shared gate.
    private let searchGate = LatestRequestGate()
    private let metricRecorder: PerformanceMetricRecorder
    private var searchMetricToken: MetricIntervalToken?

    // MARK: Init
    init(
        apiClient: APIClient = .shared,
        debounceNanoseconds: UInt64 = 400_000_000,
        loadGames: SearchLoader? = nil,
        metricRecorder: PerformanceMetricRecorder = AppObservability.shared.recorder
    ) {
        self.metricRecorder = metricRecorder
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

        let searchID = searchGate.begin()
        apply(.prepareSearch)

        // Captured by value so the task never owns the view model: the loader
        // and debounce run without a strong `self`, and every state change
        // re-enters `self` weakly on the MainActor. Releasing the view model
        // therefore runs `deinit`, which cancels this task, and cancellation
        // propagates into the loader await.
        let loadGames = self.loadGames
        let debounceNanoseconds = self.debounceNanoseconds
        let genreParameter = genre == .all ? nil : genre.rawValue

        searchTask = Task { [weak self] in
            if debounce {
                do {
                    try await Task.sleep(nanoseconds: debounceNanoseconds)
                } catch {
                    return
                }
            }
            guard self?.beginSearchIfCurrent(searchID) == true else { return }

            print("[GameSearch] request queryLength=\(normalizedQuery.count)")

            do {
                let games = try await loadGames(normalizedQuery, genreParameter)
                guard !Task.isCancelled else { return }
                print("[GameSearch] decodeSuccess resultCount=\(games.count)")
                self?.completeSearch(searchID, with: .setResults(games))
            } catch {
                guard !Task.isCancelled else { return }
                print("[GameSearch] requestFailed queryLength=\(normalizedQuery.count) errorType=\(String(describing: type(of: error)))")
                self?.completeSearch(searchID, with: .setError(L10n.Search.Error.loadFailed))
            }
        }
    }

    private func beginSearchIfCurrent(_ searchID: LatestRequestGate.Token) -> Bool {
        guard !Task.isCancelled, searchGate.isCurrent(searchID) else { return false }
        endSearchMetric(outcome: .cancelled)
        searchMetricToken = metricRecorder.begin(.searchRoundTrip)
        apply(.setSearching(true))
        return true
    }

    private func completeSearch(_ searchID: LatestRequestGate.Token, with mutation: SearchMutation) {
        guard searchGate.commit(searchID) else { return }
        if case .setError = mutation {
            endSearchMetric(outcome: .failure)
        } else {
            endSearchMetric(outcome: .success)
        }
        apply(mutation)
    }

    private func invalidateSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchGate.invalidate()
        endSearchMetric(outcome: .cancelled)
        apply(.clearResults)
    }

    private func endSearchMetric(outcome: MetricOutcome) {
        guard let token = searchMetricToken else { return }
        searchMetricToken = nil
        metricRecorder.end(token, outcome: outcome)
    }
}
