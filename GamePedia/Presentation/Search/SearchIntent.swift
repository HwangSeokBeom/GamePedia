import Foundation

// MARK: - SearchIntent

enum SearchIntent {
    case viewDidLoad
    case queryChanged(String)
    case queryCleared
    case genreSelected(SearchGenre)
    case retryTapped
    case didTapGame(id: Int)
}
