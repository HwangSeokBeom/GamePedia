import Foundation

enum ModerationError: LocalizedError, Equatable {
    case invalidReportTarget
    case invalidBlockedUser
    case persistenceFailed
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidReportTarget:
            return "신고할 콘텐츠 정보를 확인하지 못했습니다."
        case .invalidBlockedUser:
            return "차단할 사용자를 확인하지 못했습니다."
        case .persistenceFailed:
            return "요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."
        case .unknown(let message):
            return message
        }
    }

    static func from(error: Error) -> ModerationError {
        if let moderationError = error as? ModerationError {
            return moderationError
        }

        return .unknown(message: error.localizedDescription)
    }
}
