import Foundation

enum AIRecommendationError: Error, LocalizedError, Equatable {
    case validationFailed(message: String)
    case dailyLimitExceeded(message: String)
    case recommendationFailed(message: String)
    case candidateNotFound(message: String)
    case unauthorized
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(serverCode code: String?, message: String?) -> AIRecommendationError {
        let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"

        switch resolvedCode {
        case "VALIDATION_FAILED":
            return .validationFailed(message: "입력 내용을 확인해 주세요.")
        case "AI_DAILY_LIMIT_EXCEEDED":
            return .dailyLimitExceeded(message: "오늘 사용할 수 있는 AI 추천 횟수를 모두 사용했어요.")
        case "AI_RECOMMENDATION_FAILED":
            return .recommendationFailed(message: "추천을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.")
        case "CANDIDATE_NOT_FOUND":
            return .candidateNotFound(message: "조건에 맞는 게임을 찾지 못했어요. 다른 표현으로 다시 시도해 주세요.")
        case "UNAUTHORIZED":
            return .unauthorized
        default:
            return .server(
                code: resolvedCode,
                message: message ?? "추천을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
            )
        }
    }

    static func from(error: Error) -> AIRecommendationError {
        if let aiRecommendationError = error as? AIRecommendationError {
            return aiRecommendationError
        }

        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost].contains(urlError.code) {
            return .network
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .unauthorized
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
             .recommendationFailed(let message),
             .candidateNotFound(let message),
             .server(_, let message),
             .unknown(let message):
            return message
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .network:
            return "네트워크 연결을 확인해 주세요."
        case .invalidResponse:
            return "추천을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }
}
