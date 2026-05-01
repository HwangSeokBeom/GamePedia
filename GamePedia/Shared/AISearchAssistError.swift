import Foundation

enum AISearchAssistError: Error, LocalizedError, Equatable {
    case validationFailed(message: String)
    case dailyLimitExceeded(message: String)
    case candidateNotFound(message: String)
    case unauthorized
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    private static let genericFailureMessage = "AI 검색 보조를 불러오지 못했어요. 잠시 후 다시 시도해주세요."

    static func from(serverCode code: String?, message: String?) -> AISearchAssistError {
        let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"

        switch resolvedCode {
        case "AI_SEARCH_DAILY_LIMIT_EXCEEDED":
            return .dailyLimitExceeded(message: "오늘 사용할 수 있는 AI 검색 보조 횟수를 모두 사용했어요.")
        case "VALIDATION_FAILED":
            return .validationFailed(message: "검색어를 조금 더 구체적으로 입력해주세요.")
        case "UNAUTHORIZED":
            return .unauthorized
        case "CANDIDATE_NOT_FOUND":
            return .candidateNotFound(message: "조건에 맞는 게임을 찾지 못했어요. 검색어를 조금 바꿔보세요.")
        default:
            return .server(
                code: resolvedCode,
                message: genericFailureMessage
            )
        }
    }

    static func from(error: Error) -> AISearchAssistError {
        if let searchAssistError = error as? AISearchAssistError {
            return searchAssistError
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
                if containsInternalServerDetails(message) {
                    return .server(code: code?.uppercased() ?? "UNKNOWN_ERROR", message: genericFailureMessage)
                }
                return from(serverCode: code, message: message)
            case .serverError(_, let code, let message):
                if containsInternalServerDetails(message) {
                    return .server(code: code?.uppercased() ?? "UNKNOWN_ERROR", message: genericFailureMessage)
                }
                return from(serverCode: code, message: message)
            case .invalidURL, .noData, .decodingFailed:
                return .invalidResponse
            case .configurationMissing:
                return .server(code: "CONFIGURATION_MISSING", message: genericFailureMessage)
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
             .dailyLimitExceeded(let message),
             .candidateNotFound(let message),
             .server(_, let message):
            return message
        case .unknown:
            return Self.genericFailureMessage
        case .unauthorized:
            return "로그인이 필요해요."
        case .invalidResponse, .network:
            return Self.genericFailureMessage
        }
    }

    var serverCodeForLog: String {
        switch self {
        case .validationFailed:
            return "VALIDATION_FAILED"
        case .dailyLimitExceeded:
            return "AI_SEARCH_DAILY_LIMIT_EXCEEDED"
        case .candidateNotFound:
            return "CANDIDATE_NOT_FOUND"
        case .unauthorized:
            return "UNAUTHORIZED"
        case .invalidResponse:
            return "INVALID_RESPONSE"
        case .network:
            return "NETWORK"
        case .server(let code, _):
            return code
        case .unknown:
            return "UNKNOWN_ERROR"
        }
    }

    private static func containsInternalServerDetails(_ message: String?) -> Bool {
        guard let normalizedMessage = message?.lowercased() else { return false }
        let internalMarkers = [
            "route get",
            "/api/",
            "was not found",
            "prisma",
            "prismaclientknownrequesterror",
            "invalid",
            "unhandled",
            "stack",
            "error:",
            "sql"
        ]
        return internalMarkers.contains { normalizedMessage.contains($0) }
    }
}
