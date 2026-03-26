import Foundation

// MARK: - SearchIntent

enum SearchIntent {
    case viewDidLoad
    case queryChanged(String)
    case queryCleared
    case genreSelected(String)
    case didTapGame(id: Int)
}
