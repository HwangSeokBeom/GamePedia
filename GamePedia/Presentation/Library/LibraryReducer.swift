import Foundation

enum LibraryReducer {
    static func reduce(_ state: LibraryState, _ mutation: LibraryMutation) -> LibraryState {
        var state = state

        switch mutation {
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setRefreshing(let isRefreshing):
            state.isRefreshing = isRefreshing
        case .setSort(let sort):
            state.selectedSort = sort
        case .setSections(let sections):
            state.sections = sections
            state.errorMessage = nil
        case .setError(let message):
            state.errorMessage = message
            state.isLoading = false
            state.isRefreshing = false
        case .clearError:
            state.errorMessage = nil
        case .consumeInitialFocus:
            state.pendingFocusSection = nil
        }

        return state
    }
}
