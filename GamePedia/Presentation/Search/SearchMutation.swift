import Foundation

// MARK: - SearchMutation

enum SearchMutation {
    case setQuery(String)
    case setGenre(String)
    case setResults([Game])
    case setSearching(Bool)
    case clearResults
}
