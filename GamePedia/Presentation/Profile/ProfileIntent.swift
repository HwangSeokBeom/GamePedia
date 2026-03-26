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
}

enum ProfileRoute {
    case loggedOut
    case showWrittenReviews
    case showFavoriteGames
}
