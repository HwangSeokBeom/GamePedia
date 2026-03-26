import Foundation

// MARK: - ProfileIntent

enum ProfileIntent {
    case viewDidLoad
    case didTapSettings
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
}

enum ProfileRoute {
    case loggedOut
    case showWrittenReviews
    case showFavoriteGames
    case showTermsOfService
    case showPrivacyPolicy
    case showCommunityGuidelines
    case contactSupport
}
