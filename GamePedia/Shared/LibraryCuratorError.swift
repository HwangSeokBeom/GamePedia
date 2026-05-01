import Foundation

enum LibraryCuratorError: Error, LocalizedError, Equatable {
    case validationFailed(message: String)
    case dailyLimitExceeded(message: String)
    case candidateNotFound(message: String)
    case unauthorized
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(serverCode code: String?, message: String?) -> LibraryCuratorError {
        let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"

        switch resolvedCode {
        case "VALIDATION_FAILED":
            return .validationFailed(message: L10n.tr("Localizable", "library_curator_error_message"))
        case "AI_DAILY_LIMIT_EXCEEDED", "AI_LIBRARY_DAILY_LIMIT_EXCEEDED", "AI_LIBRARY_CURATOR_DAILY_LIMIT_EXCEEDED":
            return .dailyLimitExceeded(message: L10n.tr("Localizable", "library_curator_daily_limit_message"))
        case "CANDIDATE_NOT_FOUND", "NO_CANDIDATES":
            return .candidateNotFound(message: L10n.tr("Localizable", "library_curator_empty_message"))
        case "UNAUTHORIZED":
            return .unauthorized
        default:
            return .server(
                code: resolvedCode,
                message: message ?? L10n.tr("Localizable", "library_curator_error_message")
            )
        }
    }

    static func from(error: Error) -> LibraryCuratorError {
        if let libraryCuratorError = error as? LibraryCuratorError {
            return libraryCuratorError
        }

        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost].contains(urlError.code) {
            return .network
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .unauthorized
            case .rateLimited(_, let code, let message):
                return from(serverCode: code, message: message)
            case .serverError(_, let code, let message):
                return from(serverCode: code, message: message)
            case .invalidURL, .noData, .decodingFailed:
                return .invalidResponse
            case .configurationMissing(let message):
                return .server(code: "CONFIGURATION_MISSING", message: message)
            case .unknown(let error):
                if let urlError = error as? URLError,
                   [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost].contains(urlError.code) {
                    return .network
                }
                return .network
            }
        }

        return .unknown(message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .dailyLimitExceeded(let message),
             .validationFailed(let message),
             .candidateNotFound(let message),
             .server(_, let message),
             .unknown(let message):
            return message
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .network:
            return L10n.Common.Error.network
        case .invalidResponse:
            return L10n.tr("Localizable", "library_curator_error_message")
        }
    }
}
