import Foundation

enum ReviewCommentError: Error, LocalizedError, Equatable {
    case unauthorized
    case invalidContent
    case commentNotFound
    case persistenceFailed
    case reviewNotFound
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .invalidContent:
            return L10n.tr("Localizable", "review.comment.error.invalidContent")
        case .commentNotFound:
            return L10n.tr("Localizable", "review.comment.error.notFound")
        case .persistenceFailed:
            return L10n.tr("Localizable", "review.comment.error.persistenceFailed")
        case .reviewNotFound:
            return L10n.tr("Localizable", "review.comment.error.reviewUnavailable")
        case .unknown(let message):
            return message
        }
    }
}
