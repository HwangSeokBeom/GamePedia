import Foundation

// MARK: - SearchState

struct SearchState {
    var query: String = ""
    var selectedGenre: String = "전체"
    var genres: [String] = ["전체", "RPG", "액션", "인디", "전략", "스포츠"]
    var results: [Game] = []
    var resultCount: Int = 0
    var isSearching: Bool = false
    var showEmptyResult: Bool = false   // true when query non-empty but 0 results
}
