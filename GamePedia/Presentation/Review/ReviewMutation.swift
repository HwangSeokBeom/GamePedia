import Foundation

// MARK: - ReviewMutation

enum ReviewMutation {
    case setRating(Float)
    case setText(String)
    case setSubmitting(Bool)
    case setDeleting(Bool)
    case setSubmitSuccess
    case setDeleteSuccess
    case setError(String)
}
