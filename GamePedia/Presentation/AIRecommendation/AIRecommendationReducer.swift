import Foundation

enum AIRecommendationReducer {
    static func reduce(_ state: AIRecommendationState, _ mutation: AIRecommendationMutation) -> AIRecommendationState {
        var state = state

        switch mutation {
        case .setQuery(let query):
            state.query = query
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setRecommendations(let recommendations):
            state.recommendations = recommendations
            state.errorMessage = nil
            state.hasRequestedRecommendations = true
            state.isStale = false
        case .setErrorMessage(let message):
            state.errorMessage = message
            state.hasRequestedRecommendations = message != nil || state.hasRequestedRecommendations
        case .setExamples(let examples):
            state.examples = examples
        case .setDisclaimer(let disclaimer):
            state.disclaimer = disclaimer
        case .setHasRequestedRecommendations(let hasRequestedRecommendations):
            state.hasRequestedRecommendations = hasRequestedRecommendations
        case .setPersonalizationMetadata(
            let personalizationUsed,
            let personalizationAvailable,
            let fallbackUsed,
            let recommendationSource,
            let generatedAt
        ):
            state.personalizationUsed = personalizationUsed
            state.personalizationAvailable = personalizationAvailable
            state.fallbackUsed = fallbackUsed
            state.recommendationSource = recommendationSource
            state.generatedAt = generatedAt
        case .setStale(let isStale):
            state.isStale = isStale
        case .setFavorite(let gameId, let isFavorite):
            state.recommendations = state.recommendations.map { item in
                guard item.gameId == gameId else { return item }
                var updatedItem = item
                updatedItem.isFavorite = isFavorite
                return updatedItem
            }
        case .setFavoriteUpdating(let gameId, let isUpdating):
            state.recommendations = state.recommendations.map { item in
                guard item.gameId == gameId else { return item }
                var updatedItem = item
                updatedItem.isFavoriteUpdating = isUpdating
                return updatedItem
            }
        }

        return state
    }
}
