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
            state.translatedTitles = [:]
            state.translatedSummaries = [:]
        case .setSearching(let isSearching):
            state.isSearching = isSearching
        case .clearResults:
            state.results = []
            state.resultCount = 0
            state.showEmptyResult = false
            state.translatedTitles = [:]
            state.translatedSummaries = [:]
        case .setTranslatedFields(let titles, let summaries):
            state.translatedTitles.merge(titles) { _, new in new }
            state.translatedSummaries.merge(summaries) { _, new in new }
            if !titles.isEmpty {
                print("[Translation] reducer applied translatedTitle")
            }
            if !summaries.isEmpty {
                print("[Translation] reducer applied translatedSummary")
            }
        }
        return state
    }
}
