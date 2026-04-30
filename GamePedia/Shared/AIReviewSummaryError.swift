import Foundation

enum AIReviewSummaryError: Error, LocalizedError, Equatable {
    case validationFailed(message: String)
    case unauthorized
    case notAvailable(message: String)
    case dailyLimitExceeded(message: String)
    case summaryFailed(message: String)
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(serverCode code: String?, message: String?) -> AIReviewSummaryError {
        let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"

        switch resolvedCode {
        case "VALIDATION_FAILED":
            return .validationFailed(message: "요청 정보를 확인해 주세요.")
        case "UNAUTHORIZED":
            return .unauthorized
        case "REVIEW_SUMMARY_NOT_AVAILABLE":
            return .notAvailable(message: "아직 요약할 리뷰가 충분하지 않아요.")
        case "AI_DAILY_LIMIT_EXCEEDED":
            return .dailyLimitExceeded(message: "오늘 사용할 수 있는 AI 요약 횟수를 모두 사용했어요.")
        case "AI_REVIEW_SUMMARY_FAILED":
            return .summaryFailed(message: "AI 리뷰 요약을 불러오지 못했습니다.")
        default:
            return .server(
                code: resolvedCode,
                message: message ?? "AI 리뷰 요약을 불러오지 못했습니다."
            )
        }
    }

    static func from(error: Error) -> AIReviewSummaryError {
        if let summaryError = error as? AIReviewSummaryError {
            return summaryError
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
        case .validationFailed(let message),
             .notAvailable(let message),
             .dailyLimitExceeded(let message),
             .summaryFailed(let message),
             .server(_, let message),
             .unknown(let message):
            return message
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .invalidResponse:
            return "AI 리뷰 요약을 불러오지 못했습니다."
        case .network:
            return "네트워크 연결을 확인해 주세요."
        }
    }
}
