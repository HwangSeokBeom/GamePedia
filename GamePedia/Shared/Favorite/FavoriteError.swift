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
                let resolvedMessage = message ?? "찜 요청을 처리하지 못했습니다."
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
            return "로그인이 필요합니다."
        case .invalidGameId:
            return "유효한 게임 정보를 찾지 못했습니다."
        case .invalidSort:
            return "정렬 옵션이 올바르지 않습니다."
        case .validationFailed(let message):
            return message
        case .invalidResponse:
            return "서버 응답을 처리하지 못했습니다."
        case .network:
            return "네트워크 연결을 확인해주세요."
        case .server(_, let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}
