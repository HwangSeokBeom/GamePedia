import Foundation

enum AuthError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyExists
    case nicknameAlreadyExists
    case accountDeletionUnavailable
    case appleLoginUnavailable
    case googleLoginUnavailable
    case googleLoginNotConfigured
    case socialLoginCancelled
    case emptyPasswordResetToken
    case passwordResetTokenInvalid
    case passwordResetTokenExpired
    case passwordResetTokenUsed
    case tokenExpired
    case unauthorized
    case validationFailed(message: String)
    case invalidEmailFormat
    case passwordTooShort
    case passwordMismatch
    case emptyNickname
    case missingRefreshToken
    case invalidResponse
    case networkError
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(serverCode: String, message: String) -> AuthError {
        switch serverCode.uppercased() {
        case "INVALID_CREDENTIALS":
            return .invalidCredentials
        case "EMAIL_ALREADY_EXISTS", "EMAIL_ALREADY_IN_USE":
            return .emailAlreadyExists
        case "NICKNAME_ALREADY_EXISTS", "NICKNAME_ALREADY_IN_USE", "DUPLICATE_NICKNAME":
            return .nicknameAlreadyExists
        case "ACCOUNT_DELETION_UNAVAILABLE":
            return .accountDeletionUnavailable
        case "APPLE_LOGIN_UNAVAILABLE", "APPLE_AUTH_NOT_CONFIGURED", "APPLE_AUTH_UNAVAILABLE":
            return .appleLoginUnavailable
        case "GOOGLE_AUTH_NOT_CONFIGURED":
            return .googleLoginNotConfigured
        case "GOOGLE_AUTH_UNAVAILABLE":
            return .googleLoginUnavailable
        case "PASSWORD_RESET_TOKEN_INVALID":
            return .passwordResetTokenInvalid
        case "PASSWORD_RESET_TOKEN_EXPIRED":
            return .passwordResetTokenExpired
        case "PASSWORD_RESET_TOKEN_USED":
            return .passwordResetTokenUsed
        case "TOKEN_EXPIRED":
            return .tokenExpired
        case "UNAUTHORIZED":
            return .unauthorized
        case "VALIDATION_FAILED", "VALIDATION_ERROR":
            return .validationFailed(message: message)
        case "NETWORK_ERROR":
            return .networkError
        default:
            return .server(code: serverCode, message: message)
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return L10n.tr("Localizable", "auth.error.invalidCredentials")
        case .emailAlreadyExists:
            return L10n.tr("Localizable", "auth.error.emailAlreadyExists")
        case .nicknameAlreadyExists:
            return L10n.tr("Localizable", "auth.error.nicknameAlreadyExists")
        case .accountDeletionUnavailable:
            return L10n.tr("Localizable", "auth.error.accountDeletionUnavailable")
        case .appleLoginUnavailable:
            return L10n.tr("Localizable", "auth.error.appleLoginUnavailable")
        case .googleLoginUnavailable:
            return L10n.tr("Localizable", "auth.error.googleLoginUnavailable")
        case .googleLoginNotConfigured:
            return L10n.tr("Localizable", "auth.error.googleLoginNotConfigured")
        case .socialLoginCancelled:
            return nil
        case .emptyPasswordResetToken:
            return L10n.tr("Localizable", "auth.error.emptyPasswordResetToken")
        case .passwordResetTokenInvalid:
            return L10n.tr("Localizable", "auth.error.passwordResetTokenInvalid")
        case .passwordResetTokenExpired:
            return L10n.tr("Localizable", "auth.error.passwordResetTokenExpired")
        case .passwordResetTokenUsed:
            return L10n.tr("Localizable", "auth.error.passwordResetTokenUsed")
        case .tokenExpired:
            return L10n.tr("Localizable", "auth.error.tokenExpired")
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .validationFailed(let message):
            return message
        case .invalidEmailFormat:
            return L10n.tr("Localizable", "auth.error.invalidEmailFormat")
        case .passwordTooShort:
            return L10n.tr("Localizable", "auth.error.passwordTooShort")
        case .passwordMismatch:
            return L10n.tr("Localizable", "auth.error.passwordMismatch")
        case .emptyNickname:
            return L10n.tr("Localizable", "auth.error.emptyNickname")
        case .missingRefreshToken:
            return L10n.tr("Localizable", "auth.error.missingRefreshToken")
        case .invalidResponse:
            return L10n.Common.Error.server
        case .networkError:
            return L10n.Common.Error.network
        case .server(_, let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}
