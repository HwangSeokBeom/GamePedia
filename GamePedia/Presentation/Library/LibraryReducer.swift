import Foundation

enum LibraryReducer {
    static func reduce(_ state: LibraryState, _ mutation: LibraryMutation) -> LibraryState {
        var state = state

        switch mutation {
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setRefreshing(let isRefreshing):
            state.isRefreshing = isRefreshing
        case .setSelectedTab(let selectedTab):
            state.selectedTab = selectedTab
            state.pendingFocusSection = selectedTab.focusedSection
        case .setSelectedHighlightChip(let selectedHighlightChip):
            state.selectedHighlightChip = selectedHighlightChip
            state.pendingFocusSection = selectedHighlightChip.focusedSection
        case .setSort(let sort):
            state.selectedSort = sort
        case .setSummaryByTab(let summaryByTab):
            let playingSummary = summaryByTab[.playing]
            print(
                "[LibrarySummaryReducer] " +
                "selectedTab=\(state.selectedTab) " +
                "mutation=setSummaryByTab " +
                "gameCount=\(playingSummary?.gameCount ?? -1) " +
                "totalPlaytimeHours=\(playingSummary?.primaryValue ?? -1) " +
                "source=\(playingSummary?.sourceDescription ?? "nil") " +
                "fallbackTriggered=\((playingSummary?.sourceDescription ?? "").hasPrefix("derived"))"
            )
            state.summaryByTab = summaryByTab
        case .setServerSummaryByTab(let serverSummaryByTab):
            let previousPlayingSummary = state.serverSummaryByTab[.playing]
            let incomingPlayingSummary = serverSummaryByTab[.playing]
            print(
                "[LibrarySummaryReducer] " +
                "selectedTab=\(state.selectedTab) " +
                "mutation=setServerSummaryByTab " +
                "gameCount=\(incomingPlayingSummary?.gameCount ?? -1) " +
                "totalPlaytimeHours=\(incomingPlayingSummary?.totalPlaytimeHours ?? -1) " +
                "source.gameCount=\(incomingPlayingSummary?.gameCountSourceField ?? "nil") " +
                "source.totalPlaytimeHours=\(incomingPlayingSummary?.totalPlaytimeHoursSourceField ?? "nil") " +
                "staleOverwriteOccurred=\(previousPlayingSummary != nil && previousPlayingSummary != incomingPlayingSummary)"
            )
            state.serverSummaryByTab = serverSummaryByTab
        case .setPreviewGeneratedAt(let generatedAt):
            state.previewGeneratedAt = generatedAt
        case .setFullGeneratedAt(let generatedAt):
            state.fullGeneratedAt = generatedAt
        case .setMergedRecentlyPlayedState(let source, let generatedAt):
            state.recentlyPlayedSource = source
            state.mergedGeneratedAt = generatedAt
        case .setSteamState(let steamLinkStatus, let isConnected, let syncStatus, let isSyncAvailable, let errorCode):
            state.steamLinkStatus = steamLinkStatus
            state.isSteamConnected = isConnected
            state.steamSyncStatus = syncStatus
            state.isSteamSyncAvailable = isSyncAvailable
            state.steamSyncErrorCode = errorCode
        case .setLibraryItems(let recentlyPlayed, let playingGames, let ownedGames, let backlogGames, let likedGames, let reviews):
            state.recentlyPlayed = recentlyPlayed
            state.playingGames = playingGames
            state.ownedGames = ownedGames
            state.backlogGames = backlogGames
            state.likedGames = likedGames
            state.reviews = reviews
        case .setPlaytimeRecommendations(let recommendations):
            state.playtimeRecommendations = recommendations
        case .setFriendRecommendations(let recommendations, let source, let emptyState):
            state.friendRecommendations = recommendations
            state.friendRecommendationsSource = source
            state.friendRecommendationsEmptyState = emptyState
        case .setSteamOwnedSyncErrorCode(let errorCode):
            state.steamOwnedSyncErrorCode = errorCode
        case .setAddingToPlaying(let identifier, let isUpdating):
            if isUpdating {
                state.addingToPlayingIdentifiers.insert(identifier)
            } else {
                state.addingToPlayingIdentifiers.remove(identifier)
            }
        case .clearAddingToPlaying:
            state.addingToPlayingIdentifiers.removeAll()
        case .setSyncingOwnedSteamLibrary(let isSyncing):
            state.isSyncingOwnedSteamLibrary = isSyncing
        case .setUnlinkingSteamAccount(let isUnlinking):
            state.isUnlinkingSteamAccount = isUnlinking
        case .setSections(let sections):
            state.sections = sections
            state.errorMessage = nil
        case .setError(let message):
            state.errorMessage = message
            state.isLoading = false
            state.isRefreshing = false
        case .setSuccessMessage(let message):
            state.successMessage = message
        case .setSteamConnectionOnboarding(let onboarding):
            state.steamConnectionOnboarding = onboarding
        case .clearSuccessMessage:
            state.successMessage = nil
        case .clearSteamConnectionOnboarding:
            state.steamConnectionOnboarding = nil
        case .clearError:
            state.errorMessage = nil
        case .consumeInitialFocus:
            state.pendingFocusSection = nil
        }

        return state
    }
}
