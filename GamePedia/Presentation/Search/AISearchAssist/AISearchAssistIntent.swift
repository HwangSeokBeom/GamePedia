import Foundation

enum AISearchAssistIntent {
    case viewDidLoad
    case queryChanged(String)
    case searchSubmitted
    case aiAssistTapped
    case suggestedQueryTapped(String)
    case retryTapped
    case itemTapped(gameId: Int)
}
