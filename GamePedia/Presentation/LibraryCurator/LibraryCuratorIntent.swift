import Foundation

enum LibraryCuratorIntent {
    case viewDidLoad
    case queryChanged(String)
    case modeSelected(LibraryCuratorMode)
    case tasteTagTapped(String)
    case genreTagTapped(String)
    case analyzeTapped
    case retryTapped
    case gameTapped(String)
    case favoriteTapped(String)
}
