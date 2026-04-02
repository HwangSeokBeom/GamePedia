import Foundation

enum ProfileRecentPlayLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case partialFailure
    case failed
}

// MARK: - ProfileState

struct ProfileState: Equatable {
    var isLoading: Bool = false
    var isLoggingOut: Bool = false
    var isDeletingAccount: Bool = false
    var isLoadingSteamLinkStatus: Bool = false
    var isUnlinkingSteamAccount: Bool = false
    var authenticatedUser: AuthUser? = nil
    var recentlyPlayedGames: [RecentGame] = []
    var recentPlayLoadState: ProfileRecentPlayLoadState = .idle
    var selectedTitle: String? = nil
    var selectedTitleKey: String? = nil
    var selectedTitles: [String] = []
    var hasExplicitSelectedTitles: Bool? = nil
    var availableTitles: [String] = []
    var profileTags: [String] = []
    var writtenReviewCount: Int = 0
    var friendCount: Int = 0
    var friendActivityCount: Int = 0
    var wishlistCountValue: Int = 0
    var hasMoreRecentPlayed: Bool = false
    var selectedBadgeTitles: [String] = []
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
            return L10n.tr("Localizable", "profile.steam.connectedStatus", displayName)
        }

        return L10n.tr("Localizable", "profile.steam.autoSyncEnabled")
    }

    var displayName: String? { authenticatedUser?.nickname }

    var displayEmail: String? { authenticatedUser?.email }

    var displayHandle: String? {
        if let email = authenticatedUser?.email,
           let emailPrefix = email.split(separator: "@").first,
           !emailPrefix.isEmpty {
            return "@\(emailPrefix.lowercased())"
        }

        guard let nickname = authenticatedUser?.nickname, !nickname.isEmpty else { return nil }
        let normalizedNickname = nickname
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        return "@\(normalizedNickname)"
    }

    var profileImageURL: URL? {
        authenticatedUser?.profileImageUrl.flatMap(URL.init(string:))
    }

    var playedGameCount: Int { recentlyPlayedGames.count }
    var wishlistCount: Int { wishlistCountValue }

    var heroBadgeTitles: [String] {
        if selectedTitles.isEmpty == false {
            return Array(selectedTitles.prefix(1))
        }
        if let selectedTitle, selectedTitle.isEmpty == false {
            return [selectedTitle]
        }
        return []
    }

    var resolvedProfileTags: [String] {
        if profileTags.isEmpty == false {
            return profileTags
        }
        return Array(selectedBadgeTitles.prefix(1))
    }

    func resolvedTitle(for game: RecentGame) -> String {
        game.title
    }
}
