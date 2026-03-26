import Foundation

enum ReviewError: Error, LocalizedError, Equatable {
    case unauthorized
    case accountNotFound
    case reviewAlreadyExists
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
            case .unauthorized:
                return .unauthorized
            case .serverError(_, let code, let message):
                let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"
                let resolvedMessage = message ?? "리뷰 요청을 처리하지 못했습니다."
                switch resolvedCode {
                case "UNAUTHORIZED":
                    return .unauthorized
                case "ACCOUNT_NOT_FOUND":
                    return .accountNotFound
                case "REVIEW_ALREADY_EXISTS":
                    return .reviewAlreadyExists
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
            return "로그인이 필요합니다."
        case .accountNotFound:
            return "계정을 찾을 수 없습니다. 다시 로그인해주세요."
        case .reviewAlreadyExists:
            return "이미 이 게임에 대한 리뷰를 작성했습니다."
        case .reviewNotFound:
            return "리뷰를 찾을 수 없습니다."
        case .reviewForbidden:
            return "내가 작성한 리뷰만 수정하거나 삭제할 수 있습니다."
        case .invalidRating:
            return "평점은 0.5점 단위로 0.5점부터 5.0점까지 선택할 수 있습니다."
        case .invalidContent:
            return "리뷰 내용은 공백 제외 10자 이상 2000자 이하로 작성해주세요."
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
