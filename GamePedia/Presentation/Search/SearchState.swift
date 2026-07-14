import Foundation

enum SearchGenre: String, CaseIterable, Equatable {
    case all
    case rpg
    case action
    case indie
    case strategy
    case sports

    var displayName: String {
        switch self {
        case .all:
            return L10n.Search.Filter.all
        case .rpg:
            return L10n.tr("Localizable", "search.genre.rpg")
        case .action:
            return L10n.tr("Localizable", "search.genre.action")
        case .indie:
            return L10n.tr("Localizable", "search.genre.indie")
        case .strategy:
            return L10n.tr("Localizable", "search.genre.strategy")
        case .sports:
            return L10n.tr("Localizable", "search.genre.sports")
        }
    }

    func matches(canonicalGenre: String) -> Bool {
        guard self != .all else { return true }

        let normalizedGenre = Self.normalize(canonicalGenre)
        let localizedDisplayName = Self.normalize(displayName)
        if normalizedGenre.contains(localizedDisplayName) {
            return true
        }

        return canonicalTokens.contains { normalizedGenre.contains($0) }
    }

    private var canonicalTokens: [String] {
        switch self {
        case .all:
            return []
        case .rpg:
            return ["rpg", "role playing", "roleplaying"]
        case .action:
            return ["action"]
        case .indie:
            return ["indie", "independent"]
        case .strategy:
            return ["strategy"]
        case .sports:
            return ["sport", "sports"]
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - SearchState

struct SearchState {
    var query: String = ""
    var selectedGenre: SearchGenre = .all
    var genres: [SearchGenre] = SearchGenre.allCases
    var results: [Game] = []
    var resultCount: Int = 0
    var isSearching: Bool = false
    var showEmptyResult: Bool = false   // true when query non-empty but 0 results
    var errorMessage: String?
    var hasCompletedSearch: Bool = false
}

struct SearchPresentationState: Equatable {
    let showResults: Bool
    let showResultCount: Bool
    let showEmpty: Bool
    let showError: Bool
    let showAISearchAssistNotice: Bool
    let isLoading: Bool

    static func resolve(
        state: SearchState,
        displayedResultCount: Int,
        hasAISearchAssistResults: Bool
    ) -> SearchPresentationState {
        let queryIsEmpty = SearchQueryPolicy.normalizedQuery(from: state.query).isEmpty
        let showError = !queryIsEmpty && state.errorMessage != nil
        let completedEmpty = !queryIsEmpty
            && state.hasCompletedSearch
            && !state.isSearching
            && displayedResultCount == 0

        return SearchPresentationState(
            showResults: !showError && displayedResultCount > 0,
            showResultCount: !queryIsEmpty
                && !showError
                && state.hasCompletedSearch
                && !(displayedResultCount == 0 && hasAISearchAssistResults),
            showEmpty: completedEmpty && !hasAISearchAssistResults && !showError,
            showError: showError,
            showAISearchAssistNotice: completedEmpty && hasAISearchAssistResults && !showError,
            isLoading: state.isSearching
        )
    }
}
