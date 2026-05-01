import Foundation

enum LibraryCuratorMutation {
    case setQuery(String)
    case setQueryFromUserInput(String)
    case setMode(LibraryCuratorMode)
    case setPrompt(mode: LibraryCuratorMode)
    case toggleTasteTag(String)
    case toggleGenreTag(String)
    case setLoading(Bool)
    case setLoaded(
        result: LibraryCuratorResult,
        summaryTitle: String?,
        summaryBody: String?,
        summaryBullets: [String],
        tasteTags: [String],
        sections: [LibraryCuratorSectionViewState],
        isFallback: Bool,
        fallbackMessage: String?,
        emptyMessage: String?,
        generatedAtText: String?
    )
    case setErrorMessage(String?)
    case setDailyLimitExceeded(message: String?, preserveResults: Bool)
    case setFavorite(gameId: String, isFavorite: Bool)
    case setFavoriteUpdating(gameId: String, isUpdating: Bool)
    case setStale(Bool)
}
