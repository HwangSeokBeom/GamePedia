import Foundation

// MARK: - ProfileState

struct ProfileState {
    var isLoading: Bool = false
    var isLoggingOut: Bool = false
    var isDeletingAccount: Bool = false
    var authenticatedUser: AuthUser? = nil
    var recentGames: [RecentGame] = []
    var errorMessage: String? = nil
    var translatedRecentGameTitles: [Int: String] = [:]

    var isAccountActionInProgress: Bool {
        isLoggingOut || isDeletingAccount
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
    var writtenReviewCount: Int { 0 }
    var wishlistCount: Int { 0 }

    func resolvedTitle(for game: RecentGame) -> String {
        translatedRecentGameTitles[game.gameId] ?? game.resolvedTitle
    }
}
