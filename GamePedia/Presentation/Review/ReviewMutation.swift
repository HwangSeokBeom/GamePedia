import Foundation

// MARK: - ReviewMutation

enum ReviewMutation {
    case setRating(Float)
    case setText(String)
    case setSpoiler(Bool)
    case setSubmitting(Bool)
    case setSubmitSuccess
    case setError(String)
}
