import Foundation

// MARK: - ProfileIntent

enum ProfileIntent {
    case viewDidLoad
    case didTapEditProfile
    case didTapSettings
    case didTapSteamUnlink
    case didTapLogout
    case didTapDeleteAccount
    case didTapGame(id: Int)
    case didTapSeeMoreRecentPlay
    case didTapWrittenReviews
    case didTapFavoriteGames
    case didTapTermsOfService
    case didTapPrivacyPolicy
    case didTapCommunityGuidelines
    case didTapContactSupport
    case didConsumeSuccessMessage
}

enum ProfileRoute {
    case loggedOut
    case showEditProfile
    case showWrittenReviews
    case showFavoriteGames
    case showTermsOfService
    case showPrivacyPolicy
    case showCommunityGuidelines
    case contactSupport
}
