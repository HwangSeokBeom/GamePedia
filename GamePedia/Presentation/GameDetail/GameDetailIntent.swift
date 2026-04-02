import Foundation

// MARK: - GameDetailIntent

enum GameDetailIntent {
    case viewDidLoad(gameId: Int)
    case didTapHaveIt
    case didTapWriteReview
    case didTapSeeAllReviews
    case didTapShare
}
