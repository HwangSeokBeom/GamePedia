import XCTest
@testable import GamePedia

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testSupersededRequestCannotOverwriteLatestResults() {
        let loader = ControlledSearchLoader()
        let firstStarted = expectation(description: "first search started")
        let secondStarted = expectation(description: "second search started")
        loader.onStart = { query in
            if query == "first" {
                firstStarted.fulfill()
            } else if query == "second" {
                secondStarted.fulfill()
            }
        }
        let viewModel = SearchViewModel(
            debounceNanoseconds: 0,
            loadGames: loader.load
        )

        viewModel.send(.queryChanged("first"))
        wait(for: [firstStarted], timeout: 1)
        viewModel.send(.queryChanged("second"))
        wait(for: [secondStarted], timeout: 1)

        let latestRendered = expectation(description: "latest result rendered")
        viewModel.onStateChanged = { state in
            if state.results.map(\.id) == [2] {
                latestRendered.fulfill()
            }
        }
        loader.resolve(query: "second", games: [makeGame(id: 2, title: "Second")])
        wait(for: [latestRendered], timeout: 1)

        loader.resolve(query: "first", games: [makeGame(id: 1, title: "First")])
        let staleResultSettled = expectation(description: "stale result ignored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            staleResultSettled.fulfill()
        }
        wait(for: [staleResultSettled], timeout: 1)

        XCTAssertEqual(viewModel.state.query, "second")
        XCTAssertEqual(viewModel.state.results.map(\.id), [2])
        XCTAssertNil(viewModel.state.errorMessage)
    }

    func testFailureShowsRetryableErrorAndRetryCanRecover() {
        let attempts = LockedCounter()
        let viewModel = SearchViewModel(
            debounceNanoseconds: 0,
            loadGames: { _, _ in
                if attempts.increment() == 1 {
                    throw StubError.unavailable
                }
                return [self.makeGame(id: 7, title: "Recovered")]
            }
        )
        let errorRendered = expectation(description: "error rendered")
        viewModel.onStateChanged = { state in
            if state.errorMessage == L10n.Search.Error.loadFailed {
                errorRendered.fulfill()
            }
        }

        viewModel.send(.queryChanged("recover"))
        wait(for: [errorRendered], timeout: 1)

        XCTAssertTrue(viewModel.state.results.isEmpty)
        XCTAssertFalse(viewModel.state.showEmptyResult)
        XCTAssertFalse(viewModel.state.isSearching)

        let recovered = expectation(description: "retry recovered")
        viewModel.onStateChanged = { state in
            if state.results.map(\.id) == [7] {
                recovered.fulfill()
            }
        }
        viewModel.send(.retryTapped)
        wait(for: [recovered], timeout: 1)

        XCTAssertEqual(attempts.value, 2)
        XCTAssertNil(viewModel.state.errorMessage)
    }

    func testClearCancelsPendingDebouncedSearchAndResetsState() {
        let requestStarted = expectation(description: "request must remain cancelled")
        requestStarted.isInverted = true
        let viewModel = SearchViewModel(
            debounceNanoseconds: 100_000_000,
            loadGames: { _, _ in
                requestStarted.fulfill()
                return []
            }
        )

        viewModel.send(.queryChanged("pending"))
        viewModel.send(.queryCleared)

        wait(for: [requestStarted], timeout: 0.2)
        XCTAssertEqual(viewModel.state.query, "")
        XCTAssertTrue(viewModel.state.results.isEmpty)
        XCTAssertFalse(viewModel.state.isSearching)
        XCTAssertFalse(viewModel.state.showEmptyResult)
        XCTAssertNil(viewModel.state.errorMessage)
    }

    func testGenreSelectionFiltersLocallyWithoutDuplicateRequest() {
        let attempts = LockedCounter()
        let resultRendered = expectation(description: "initial result rendered")
        let viewModel = SearchViewModel(
            debounceNanoseconds: 0,
            loadGames: { _, _ in
                attempts.increment()
                return [self.makeGame(id: 3, title: "Genre")]
            }
        )
        viewModel.onStateChanged = { state in
            if state.results.map(\.id) == [3] {
                resultRendered.fulfill()
            }
        }

        viewModel.send(.queryChanged("genre"))
        wait(for: [resultRendered], timeout: 1)
        // Detach the handler: .setGenre re-emits state with the same results,
        // which would over-fulfill the expectation above.
        viewModel.onStateChanged = nil
        viewModel.send(.genreSelected(.rpg))

        XCTAssertEqual(attempts.value, 1)
        XCTAssertEqual(viewModel.state.selectedGenre, .rpg)
        XCTAssertEqual(viewModel.state.results.map(\.id), [3])
    }

    func testPresentationStateSeparatesDebounceLoadingEmptyErrorAndAIAssist() {
        var state = SearchReducer.reduce(SearchState(), .setQuery("fixture"))
        state = SearchReducer.reduce(state, .prepareSearch)

        var presentation = SearchPresentationState.resolve(
            state: state,
            displayedResultCount: 0,
            hasAISearchAssistResults: false
        )
        XCTAssertFalse(presentation.showEmpty)
        XCTAssertFalse(presentation.showError)
        XCTAssertFalse(presentation.isLoading)

        state = SearchReducer.reduce(state, .setSearching(true))
        presentation = SearchPresentationState.resolve(
            state: state,
            displayedResultCount: 0,
            hasAISearchAssistResults: false
        )
        XCTAssertTrue(presentation.isLoading)
        XCTAssertFalse(presentation.showEmpty)

        state = SearchReducer.reduce(state, .setResults([]))
        presentation = SearchPresentationState.resolve(
            state: state,
            displayedResultCount: 0,
            hasAISearchAssistResults: false
        )
        XCTAssertTrue(presentation.showEmpty)
        XCTAssertFalse(presentation.showError)

        let aiPresentation = SearchPresentationState.resolve(
            state: state,
            displayedResultCount: 0,
            hasAISearchAssistResults: true
        )
        XCTAssertFalse(aiPresentation.showEmpty)
        XCTAssertTrue(aiPresentation.showAISearchAssistNotice)

        state = SearchReducer.reduce(state, .setError("Failed"))
        presentation = SearchPresentationState.resolve(
            state: state,
            displayedResultCount: 0,
            hasAISearchAssistResults: true
        )
        XCTAssertTrue(presentation.showError)
        XCTAssertFalse(presentation.showEmpty)
        XCTAssertFalse(presentation.showAISearchAssistNotice)
    }

    func testStableGenreIdentityMatchesCanonicalBackendValues() {
        XCTAssertTrue(SearchGenre.rpg.matches(canonicalGenre: "Role-playing (RPG)"))
        XCTAssertTrue(SearchGenre.action.matches(canonicalGenre: "Action"))
        XCTAssertTrue(SearchGenre.indie.matches(canonicalGenre: "Indie"))
        XCTAssertTrue(SearchGenre.strategy.matches(canonicalGenre: "Turn-based Strategy"))
        XCTAssertTrue(SearchGenre.sports.matches(canonicalGenre: "Sport"))
        XCTAssertFalse(SearchGenre.action.matches(canonicalGenre: "Strategy"))

        for genre in SearchGenre.allCases {
            XCTAssertFalse(genre.displayName.isEmpty)
        }
    }

    private func makeGame(id: Int, title: String) -> Game {
        Game(
            id: id,
            title: title,
            translatedTitle: nil,
            summary: nil,
            translatedSummary: nil,
            genre: "RPG",
            category: "RPG",
            developer: "Fixture",
            platform: "Fixture",
            releaseDate: nil,
            releaseYear: 0,
            coverImageURL: nil,
            rating: 0,
            reviewCount: 0,
            popularity: 0,
            isTrending: false,
            formattedRating: "—",
            formattedReviewCount: "—"
        )
    }
}

private enum StubError: Error {
    case unavailable
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}

private final class ControlledSearchLoader: @unchecked Sendable {
    typealias Continuation = CheckedContinuation<[Game], Never>

    private let lock = NSLock()
    private var continuations: [String: Continuation] = [:]
    var onStart: ((String) -> Void)?

    func load(query: String, genre: String?) async throws -> [Game] {
        _ = genre
        return await withCheckedContinuation { continuation in
            lock.lock()
            continuations[query] = continuation
            let onStart = onStart
            lock.unlock()
            onStart?(query)
        }
    }

    func resolve(query: String, games: [Game]) {
        lock.lock()
        let continuation = continuations.removeValue(forKey: query)
        lock.unlock()
        continuation?.resume(returning: games)
    }
}
