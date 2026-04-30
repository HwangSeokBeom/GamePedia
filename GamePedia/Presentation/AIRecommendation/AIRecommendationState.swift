import Foundation

struct AIRecommendationState {
    var query: String = ""
    var isLoading: Bool = false
    var recommendations: [AIRecommendationItemViewState] = []
    var errorMessage: String? = nil
    var examples: [String] = []
    var disclaimer: String? = nil
    var hasRequestedRecommendations: Bool = false

    var isRecommendButtonEnabled: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !isLoading
    }

    var showsEmptyState: Bool {
        hasRequestedRecommendations
            && !isLoading
            && errorMessage == nil
            && recommendations.isEmpty
    }
}

