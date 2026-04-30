import Foundation

enum AIRecommendationMutation {
    case setQuery(String)
    case setLoading(Bool)
    case setRecommendations([AIRecommendationItemViewState])
    case setErrorMessage(String?)
    case setExamples([String])
    case setDisclaimer(String?)
    case setHasRequestedRecommendations(Bool)
    case setFavorite(gameId: Int, isFavorite: Bool)
    case setFavoriteUpdating(gameId: Int, isUpdating: Bool)
}
