import Foundation

// MARK: - ProfileIntent

enum ProfileIntent {
    case viewDidLoad
    case didTapEditProfile
    case didTapSettings
    case didTapSteamUnlink
    case didTapLogout
    case didTapDeleteAccount
    case didTapPlayedGamesStat
    case didTapGame(id: Int)
    case didTapSeeMoreRecentPlay
    case didTapWrittenReviews
    case didTapFavoriteGames
    case didTapFriendsList
    case didTapSteamFriends
    case didTapFriendRequests
    case didTapFriendSearch
    case didTapFriendActivity
    case didTapSocialPrivacySettings
    case didTapTermsOfService
    case didTapPrivacyPolicy
    case didTapCommunityGuidelines
    case didTapContactSupport
    case didConsumeSuccessMessage
}

enum ProfileRoute {
    case loggedOut
    case showEditProfile
    case showSettings
    case showPlayedGames
    case showRecentPlayList
    case showWrittenReviews
    case showFavoriteGames
    case showFriendsList
    case showSteamFriends
    case showFriendRequests
    case showFriendSearch
    case showFriendActivity
    case showSocialPrivacySettings
    case showTermsOfService
    case showPrivacyPolicy
    case showCommunityGuidelines
    case contactSupport
}
