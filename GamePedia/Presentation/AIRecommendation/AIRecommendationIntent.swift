import Foundation

enum AIRecommendationIntent {
    case viewDidLoad
    case queryChanged(String)
    case exampleChipTapped(String)
    case recommendButtonTapped
    case gameTapped(gameId: Int)
    case favoriteTapped(gameId: Int)
    case retryTapped
    case refreshTapped
}
