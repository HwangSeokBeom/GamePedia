import Foundation

enum ModerationError: LocalizedError, Equatable {
    case invalidReportTarget
    case invalidBlockedUser
    case persistenceFailed
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidReportTarget:
            return L10n.tr("Localizable", "moderation.error.invalidReportTarget")
        case .invalidBlockedUser:
            return L10n.tr("Localizable", "moderation.error.invalidBlockedUser")
        case .persistenceFailed:
            return L10n.tr("Localizable", "moderation.error.persistenceFailed")
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
