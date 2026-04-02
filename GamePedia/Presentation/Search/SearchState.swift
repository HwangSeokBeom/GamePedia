import Foundation

// MARK: - SearchState

struct SearchState {
    var query: String = ""
    var selectedGenre: String = L10n.Search.Filter.all
    var genres: [String] = [
        L10n.Search.Filter.all,
        L10n.tr("Localizable", "search.genre.rpg"),
        L10n.tr("Localizable", "search.genre.action"),
        L10n.tr("Localizable", "search.genre.indie"),
        L10n.tr("Localizable", "search.genre.strategy"),
        L10n.tr("Localizable", "search.genre.sports")
    ]
    var results: [Game] = []
    var resultCount: Int = 0
    var isSearching: Bool = false
    var showEmptyResult: Bool = false   // true when query non-empty but 0 results
}
