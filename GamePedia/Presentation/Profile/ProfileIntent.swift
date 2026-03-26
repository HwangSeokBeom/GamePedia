import Foundation

// MARK: - ProfileIntent

enum ProfileIntent {
    case viewDidLoad
    case didTapSettings
    case didTapLogout
    case didTapDeleteAccount
    case didTapGame(id: Int)
    case didTapSeeMoreRecentPlay
}

enum ProfileRoute {
    case loggedOut
}
