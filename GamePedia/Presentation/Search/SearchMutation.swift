import Foundation

// MARK: - SearchMutation

enum SearchMutation {
    case setQuery(String)
    case setGenre(SearchGenre)
    case prepareSearch
    case setResults([Game])
    case setSearching(Bool)
    case setError(String)
    case clearResults
}
