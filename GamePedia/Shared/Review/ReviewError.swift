import Foundation

enum ReviewError: Error, LocalizedError, Equatable {
    case unauthorized
    case accountNotFound
    case reviewNotFound
    case reviewForbidden
    case invalidRating
    case invalidContent
    case validationFailed(message: String)
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(error: Error) -> ReviewError {
        if let reviewError = error as? ReviewError {
            return reviewError
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .configurationMissing(let message):
                return .server(code: "CONFIGURATION_MISSING", message: message)
            case .unauthorized:
                return .unauthorized
            case .serverError(_, let code, let message):
                let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"
                let resolvedMessage = message ?? L10n.tr("Localizable", "review.error.requestFailed")
                switch resolvedCode {
                case "UNAUTHORIZED":
                    return .unauthorized
                case "ACCOUNT_NOT_FOUND":
                    return .accountNotFound
                case "REVIEW_NOT_FOUND":
                    return .reviewNotFound
                case "REVIEW_FORBIDDEN":
                    return .reviewForbidden
                case "INVALID_RATING":
                    return .invalidRating
                case "INVALID_REVIEW_CONTENT":
                    return .invalidContent
                case "VALIDATION_ERROR":
                    return .validationFailed(message: resolvedMessage)
                default:
                    return .server(code: resolvedCode, message: resolvedMessage)
                }
            case .invalidURL, .noData:
                return .invalidResponse
            case .decodingFailed:
                return .invalidResponse
            case .unknown:
                return .network
            }
        }

        return .unknown(message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .accountNotFound:
            return L10n.tr("Localizable", "review.error.accountNotFound")
        case .reviewNotFound:
            return L10n.tr("Localizable", "review.error.notFound")
        case .reviewForbidden:
            return L10n.tr("Localizable", "review.error.forbidden")
        case .invalidRating:
            return L10n.tr("Localizable", "review.error.invalidRating")
        case .invalidContent:
            return L10n.tr("Localizable", "review.error.invalidContent")
        case .validationFailed(let message):
            return message
        case .invalidResponse:
            return L10n.Common.Error.server
        case .network:
            return L10n.Common.Error.network
        case .server(_, let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}
