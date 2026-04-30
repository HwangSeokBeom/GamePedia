import Foundation

enum AISearchAssistReducer {
    static func reduce(_ state: AISearchAssistState, _ mutation: AISearchAssistMutation) -> AISearchAssistState {
        var state = state

        switch mutation {
        case .setQuery(let query):
            state.query = query
            state.canRequestAISearch = Self.canRequestAISearch(for: query)
            state.status = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .idle : .typing
            state.errorMessage = nil
            state.items = []
            state.suggestedQueries = []
            state.intentChips = []
            state.normalizedQuery = nil
            state.fallbackUsed = false
            state.disclaimer = nil
        case .setLoading(let isLoading):
            state.isLoading = isLoading
            if isLoading {
                state.status = .loading
                state.errorMessage = nil
            }
        case .setLoaded(
            let items,
            let suggestedQueries,
            let intentChips,
            let normalizedQuery,
            let fallbackUsed,
            let disclaimer,
            let requestSignature
        ):
            state.isLoading = false
            state.status = items.isEmpty ? .empty : .loaded
            state.items = items
            state.suggestedQueries = suggestedQueries
            state.intentChips = intentChips
            state.normalizedQuery = normalizedQuery
            state.fallbackUsed = fallbackUsed
            state.disclaimer = disclaimer
            state.errorMessage = nil
            state.lastRequestedSignature = requestSignature
        case .setEmpty(let message, let requestSignature):
            state.isLoading = false
            state.status = .empty
            state.items = []
            state.errorMessage = message
            state.lastRequestedSignature = requestSignature
        case .setError(let message):
            state.isLoading = false
            state.status = .error
            state.errorMessage = message
        case .setDailyLimitExceeded(let message):
            state.isLoading = false
            state.status = .dailyLimitExceeded
            state.errorMessage = message
        case .setUnauthorized(let message):
            state.isLoading = false
            state.status = .unauthorized
            state.errorMessage = message
        case .clearResult:
            state = AISearchAssistState()
        case .setRequestToken(let token):
            state.currentRequestToken = token
        }

        return state
    }

    static func canRequestAISearch(for query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return false }
        return trimmedQuery.count >= 8 || trimmedQuery.contains(where: { $0.isWhitespace })
    }
}
