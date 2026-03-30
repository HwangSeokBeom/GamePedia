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
        case .setSteamState(let isConnected, let isSyncAvailable, let errorCode):
            state.isSteamConnected = isConnected
            state.isSteamSyncAvailable = isSyncAvailable
            state.steamSyncErrorCode = errorCode
        case .setLibraryItems(let recentlyPlayed, let playingGames, let likedGames, let reviews):
            state.recentlyPlayed = recentlyPlayed
            state.playingGames = playingGames
            state.likedGames = likedGames
            state.reviews = reviews
        case .setAddingToPlaying(let identifier, let isUpdating):
            if isUpdating {
                state.addingToPlayingIdentifiers.insert(identifier)
            } else {
                state.addingToPlayingIdentifiers.remove(identifier)
            }
        case .clearAddingToPlaying:
            state.addingToPlayingIdentifiers.removeAll()
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
