import Foundation

enum FavoriteError: Error, LocalizedError, Equatable {
    case unauthorized
    case invalidGameId
    case invalidSort
    case validationFailed(message: String)
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(error: Error) -> FavoriteError {
        if let favoriteError = error as? FavoriteError {
            return favoriteError
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .configurationMissing(let message):
                return .server(code: "CONFIGURATION_MISSING", message: message)
            case .unauthorized:
                return .unauthorized
            case .serverError(_, let code, let message):
                let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"
                let resolvedMessage = message ?? L10n.tr("Localizable", "favorite.error.requestFailed")
                switch resolvedCode {
                case "UNAUTHORIZED":
                    return .unauthorized
                case "INVALID_GAME_ID":
                    return .invalidGameId
                case "INVALID_FAVORITE_SORT":
                    return .invalidSort
                case "VALIDATION_ERROR":
                    return .validationFailed(message: resolvedMessage)
                default:
                    return .server(code: resolvedCode, message: resolvedMessage)
                }
            case .invalidURL, .noData, .decodingFailed:
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
        case .invalidGameId:
            return L10n.tr("Localizable", "favorite.error.invalidGameId")
        case .invalidSort:
            return L10n.tr("Localizable", "favorite.error.invalidSort")
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
