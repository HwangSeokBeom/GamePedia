import Foundation

// MARK: - ProfileState

struct ProfileState {
    var isLoading: Bool = false
    var isLoggingOut: Bool = false
    var isDeletingAccount: Bool = false
    var isLoadingSteamLinkStatus: Bool = false
    var isUnlinkingSteamAccount: Bool = false
    var authenticatedUser: AuthUser? = nil
    var recentGames: [RecentGame] = []
    var writtenReviewCount: Int = 0
    var wishlistCountValue: Int = 0
    var steamLinkStatus: SteamLinkStatus = .notLinked
    var errorMessage: String? = nil
    var successMessage: String? = nil
    var translatedRecentGameTitles: [Int: String] = [:]

    var isAccountActionInProgress: Bool {
        isLoggingOut || isDeletingAccount || isUnlinkingSteamAccount
    }

    var isSteamConnected: Bool {
        steamLinkStatus.isLinked
    }

    var steamConnectionSubtitle: String {
        if let displayName = steamLinkStatus.displayName,
           displayName.isEmpty == false {
            return "\(displayName) · 자동 동기화 활성화됨"
        }

        return "자동 동기화 활성화됨"
    }

    var displayName: String? { authenticatedUser?.nickname }

    var displayEmail: String? { authenticatedUser?.email }

    var profileImageURL: URL? {
        authenticatedUser?.profileImageUrl.flatMap(URL.init(string:))
    }

    var badgeTitle: String? {
        guard let status = authenticatedUser?.status else { return nil }

        switch status.uppercased() {
        case "ACTIVE":
            return "활성 사용자"
        default:
            return status
        }
    }

    var playedGameCount: Int { recentGames.count }
    var wishlistCount: Int { wishlistCountValue }

    func resolvedTitle(for game: RecentGame) -> String {
        translatedRecentGameTitles[game.gameId] ?? game.resolvedTitle
    }
}
