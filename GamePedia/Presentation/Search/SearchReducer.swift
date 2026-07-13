import Foundation

// MARK: - SearchReducer

enum SearchReducer {
    static func reduce(_ state: SearchState, _ mutation: SearchMutation) -> SearchState {
        var state = state
        switch mutation {
        case .setQuery(let q):
            state.query = q
        case .setGenre(let genre):
            state.selectedGenre = genre
        case .prepareSearch:
            state.results = []
            state.resultCount = 0
            state.isSearching = false
            state.showEmptyResult = false
            state.errorMessage = nil
            state.hasCompletedSearch = false
        case .setResults(let games):
            state.results = games
            state.resultCount = games.count
            state.showEmptyResult = !state.query.isEmpty && games.isEmpty
            state.isSearching = false
            state.errorMessage = nil
            state.hasCompletedSearch = true
        case .setSearching(let isSearching):
            state.isSearching = isSearching
            if isSearching {
                state.errorMessage = nil
            }
        case .setError(let message):
            state.results = []
            state.resultCount = 0
            state.isSearching = false
            state.showEmptyResult = false
            state.errorMessage = message
            state.hasCompletedSearch = false
        case .clearResults:
            state.results = []
            state.resultCount = 0
            state.isSearching = false
            state.showEmptyResult = false
            state.errorMessage = nil
            state.hasCompletedSearch = false
        }
        return state
    }
}
