import Foundation

struct AIRecommendationState {
    var query: String = ""
    var isLoading: Bool = false
    var recommendations: [AIRecommendationItemViewState] = []
    var errorMessage: String? = nil
    var examples: [String] = []
    var disclaimer: String? = nil
    var hasRequestedRecommendations: Bool = false
    var personalizationUsed: Bool? = nil
    var personalizationAvailable: Bool? = nil
    var fallbackUsed: Bool? = nil
    var recommendationSource: String? = nil
    var generatedAt: String? = nil
    var isStale: Bool = false

    var isRecommendButtonEnabled: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !isLoading
    }

    var showsEmptyState: Bool {
        hasRequestedRecommendations
            && !isLoading
            && errorMessage == nil
            && recommendations.isEmpty
    }

    var emptyMessage: String {
        if personalizationAvailable == false {
            return L10n.tr("Localizable", "ai_recommendation_empty_personalized_result")
        }
        return L10n.tr("Localizable", "aiRecommendation.emptyMessage")
    }

    var helperMessage: String? {
        if isStale {
            return L10n.tr("Localizable", "ai_recommendation_stale_notice")
        }
        if fallbackUsed == true {
            return L10n.tr("Localizable", "ai_recommendation_fallback_notice")
        }
        if personalizationUsed == true {
            return L10n.tr("Localizable", "ai_recommendation_personalized_notice")
        }
        if personalizationAvailable == false {
            return L10n.tr("Localizable", "ai_recommendation_personalization_unavailable_notice")
        }
        return nil
    }
}
