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

    static let emptyMessage = "아직 요약할 리뷰가 충분하지 않아요."
    private static let genericFailureMessage = "AI 리뷰 요약을 불러오지 못했어요. 잠시 후 다시 시도해주세요."
    private static let unavailableMessage = "AI 리뷰 요약을 아직 제공할 수 없어요."

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
                message: genericFailureMessage
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
            case .serverError(let statusCode, let code, let message):
                if statusCode == 404 || containsInternalServerDetails(message) {
                    return .notAvailable(message: unavailableMessage)
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

    var userFacingMessage: String {
        switch self {
        case .validationFailed(let message),
             .notAvailable(let message),
             .dailyLimitExceeded(let message),
             .summaryFailed(let message):
            return message
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .network:
            return "네트워크 연결을 확인해 주세요."
        case .invalidResponse,
             .server,
             .unknown:
            return Self.genericFailureMessage
        }
    }

    var shouldRenderAsEmpty: Bool {
        if case .notAvailable = self { return true }
        return false
    }

    var isRetryAvailable: Bool {
        switch self {
        case .notAvailable, .dailyLimitExceeded, .unauthorized, .validationFailed:
            return false
        case .summaryFailed, .invalidResponse, .network, .server, .unknown:
            return true
        }
    }

    var logCode: String {
        switch self {
        case .validationFailed:
            return "VALIDATION_FAILED"
        case .unauthorized:
            return "UNAUTHORIZED"
        case .notAvailable:
            return "REVIEW_SUMMARY_NOT_AVAILABLE"
        case .dailyLimitExceeded:
            return "AI_DAILY_LIMIT_EXCEEDED"
        case .summaryFailed:
            return "AI_REVIEW_SUMMARY_FAILED"
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

    func debugMessage(from error: Error) -> String {
        Self.redactedForDebugLog(error.localizedDescription)
    }

    var errorDescription: String? {
        userFacingMessage
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

    private static func redactedForDebugLog(_ message: String) -> String {
        var redactedMessage = message
        let patterns = [
            #"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s,]+"#,
            #"(?i)((access|refresh)?token\s*[:=]\s*)[^\s,]+"#,
            #"(?i)(jwt\s*[:=]\s*)[^\s,]+"#
        ]

        patterns.forEach { pattern in
            redactedMessage = redactedMessage.replacingOccurrences(
                of: pattern,
                with: "$1<redacted>",
                options: .regularExpression
            )
        }

        return redactedMessage
    }
}
