import Foundation

enum AISearchAssistMutation {
    case setQuery(String)
    case setLoading(Bool)
    case setLoaded(
        items: [AISearchAssistItemViewState],
        suggestedQueries: [String],
        intentChips: [String],
        normalizedQuery: String?,
        fallbackUsed: Bool,
        disclaimer: String?,
        requestSignature: String
    )
    case setEmpty(message: String?, requestSignature: String)
    case setError(String)
    case setDailyLimitExceeded(String)
    case setUnauthorized(String)
    case clearResult
    case setRequestToken(UUID?)
}
