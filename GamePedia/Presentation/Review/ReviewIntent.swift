import Foundation

// MARK: - ReviewIntent

enum ReviewIntent {
    case viewDidLoad
    case ratingChanged(Float)
    case textChanged(String)
    case spoilerToggled(Bool)
    case didTapSubmit
}
