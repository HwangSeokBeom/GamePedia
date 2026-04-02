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
        case .setLoadingSteamLinkStatus(let isLoadingSteamLinkStatus):
            state.isLoadingSteamLinkStatus = isLoadingSteamLinkStatus
        case .setUnlinkingSteamAccount(let isUnlinkingSteamAccount):
            state.isUnlinkingSteamAccount = isUnlinkingSteamAccount
        case .setAuthenticatedUser(let authenticatedUser):
            state.authenticatedUser = authenticatedUser
            state.isLoading = false
        case .setProfileSummary(let profileSummary):
            let resolvedSelectedTitle = profileSummary.resolvedBadgeTitle
            state.selectedTitle = resolvedSelectedTitle
            state.selectedTitleKey = ProfileBadgeSelectionStore.shared.selectedTitleKey(for: resolvedSelectedTitle)
            state.hasExplicitSelectedTitles = profileSummary.explicitSelected
            state.selectedTitles = resolvedSelectedTitle.map { [$0] } ?? []
            state.selectedBadgeTitles = resolvedSelectedTitle.map { [$0] } ?? []
            state.availableTitles = profileSummary.availableTitles
            state.profileTags = profileSummary.profileTags
            state.friendCount = profileSummary.friendCount
            state.wishlistCountValue = profileSummary.likeCount
            state.hasMoreRecentPlayed = profileSummary.hasMoreRecentPlayed
            state.isLoading = false
        case .setRecentlyPlayedGames(let games):
            state.recentlyPlayedGames = games
            state.translatedRecentGameTitles = [:]
            if games.isEmpty {
                if state.recentPlayLoadState == .loading {
                    state.recentPlayLoadState = .empty
                }
            } else {
                state.recentPlayLoadState = .loaded
            }
        case .setRecentPlayLoadState(let loadState):
            state.recentPlayLoadState = loadState
        case .setWrittenReviewCount(let count):
            state.writtenReviewCount = count
        case .setFriendCount(let count):
            state.friendCount = count
        case .setFriendActivityCount(let count):
            state.friendActivityCount = count
        case .setWishlistCount(let count):
            state.wishlistCountValue = count
        case .setHasMoreRecentPlayed(let hasMoreRecentPlayed):
            state.hasMoreRecentPlayed = hasMoreRecentPlayed
        case .setSelectedTitles(let selectedTitles):
            let uniqueTitles = Array(NSOrderedSet(array: selectedTitles).array as? [String] ?? [])
            state.selectedTitles = Array(uniqueTitles.prefix(1))
            state.hasExplicitSelectedTitles = state.selectedTitles.isEmpty == false
            state.selectedTitle = state.selectedTitles.first
            state.selectedTitleKey = ProfileBadgeSelectionStore.shared.selectedTitleKey(for: state.selectedTitle)
        case .setSelectedTitleSelection(let title, let key):
            let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            state.selectedTitle = normalizedTitle?.isEmpty == false ? normalizedTitle : nil
            state.selectedTitleKey = key
            state.selectedTitles = state.selectedTitle.map { [$0] } ?? []
            state.selectedBadgeTitles = state.selectedTitle.map { [$0] } ?? []
            state.hasExplicitSelectedTitles = state.selectedTitle != nil
        case .setSelectedBadgeTitles(let badgeTitles):
            state.selectedBadgeTitles = Array(NSOrderedSet(array: badgeTitles).array as? [String] ?? []).prefix(1).map { $0 }
        case .setSteamLinkStatus(let steamLinkStatus):
            state.steamLinkStatus = steamLinkStatus
            state.isLoadingSteamLinkStatus = false
        case .setError(let msg):
            state.errorMessage = msg
            state.isLoading = false
            state.isLoadingSteamLinkStatus = false
            state.isUnlinkingSteamAccount = false
        case .setSuccessMessage(let message):
            state.successMessage = message
        case .clearError:
            state.errorMessage = nil
        case .clearSuccessMessage:
            state.successMessage = nil
        case .setTranslatedRecentGameTitles(let recentGameTitles):
            state.translatedRecentGameTitles.merge(recentGameTitles) { _, new in new }
        }
        return state
    }
}
