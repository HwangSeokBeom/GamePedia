import Foundation

enum AISearchAssistStatus: Equatable {
    case idle
    case typing
    case loading
    case loaded
    case empty
    case error
    case dailyLimitExceeded
    case unauthorized
}

struct AISearchAssistState: Equatable {
    var status: AISearchAssistStatus = .idle
    var query: String = ""
    var isLoading: Bool = false
    var items: [AISearchAssistItemViewState] = []
    var suggestedQueries: [String] = []
    var intentChips: [String] = []
    var normalizedQuery: String?
    var errorMessage: String?
    var fallbackUsed: Bool = false
    var disclaimer: String?
    var currentRequestToken: UUID?
    var canRequestAISearch: Bool = false
    var lastRequestedSignature: String?

    var shouldShowSection: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || status != .idle
            || !items.isEmpty
    }

    var hasResults: Bool {
        !items.isEmpty
    }

    var shouldShowCTA: Bool {
        canRequestAISearch
            && !isLoading
            && status != .loaded
            && status != .dailyLimitExceeded
            && status != .unauthorized
    }

    var subtitleText: String {
        if let normalizedQuery, !normalizedQuery.isEmpty {
            return normalizedQuery
        }
        switch status {
        case .loaded, .empty:
            return "검색 의도를 분석했어요"
        case .loading:
            return "검색 의도를 분석하는 중이에요"
        default:
            return "문장 검색은 AI로 의도를 분석할 수 있어요"
        }
    }
}
