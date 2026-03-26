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
        case .setResults(let games):
            state.results = games
            state.resultCount = games.count
            state.showEmptyResult = !state.query.isEmpty && games.isEmpty
            state.isSearching = false
        case .setSearching(let isSearching):
            state.isSearching = isSearching
        case .clearResults:
            state.results = []
            state.resultCount = 0
            state.showEmptyResult = false
        }
        return state
    }
}
