import Foundation

// MARK: - ProfileReducer

enum ProfileReducer {
    static func reduce(_ state: ProfileState, _ mutation: ProfileMutation) -> ProfileState {
        var state = state
        switch mutation {
        case .setLoading(let v):
            state.isLoading = v
        case .setLoggingOut(let isLoggingOut):
            state.isLoggingOut = isLoggingOut
        case .setDeletingAccount(let isDeletingAccount):
            state.isDeletingAccount = isDeletingAccount
        case .setAuthenticatedUser(let authenticatedUser):
            state.authenticatedUser = authenticatedUser
            state.isLoading = false
        case .setRecentGames(let g):
            state.recentGames = g
            state.translatedRecentGameTitles = [:]
        case .setWrittenReviewCount(let count):
            state.writtenReviewCount = count
        case .setError(let msg):
            state.errorMessage = msg
            state.isLoading = false
        case .clearError:
            state.errorMessage = nil
        case .setTranslatedRecentGameTitles(let recentGameTitles):
            state.translatedRecentGameTitles.merge(recentGameTitles) { _, new in new }
        }
        return state
    }
}
