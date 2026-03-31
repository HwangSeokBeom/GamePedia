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
            return "이메일 또는 비밀번호를 다시 확인해주세요."
        case .emailAlreadyExists:
            return "이미 가입된 이메일입니다."
        case .nicknameAlreadyExists:
            return "이미 사용 중인 닉네임이에요"
        case .accountDeletionUnavailable:
            return "현재 서버에서 회원 탈퇴를 지원하지 않습니다. 잠시 후 다시 시도해주세요."
        case .appleLoginUnavailable:
            return "현재 Apple 로그인을 사용할 수 없습니다. 잠시 후 다시 시도해주세요."
        case .googleLoginUnavailable:
            return "현재 Google 로그인을 사용할 수 없습니다. 잠시 후 다시 시도해주세요."
        case .googleLoginNotConfigured:
            return "Google 로그인 설정이 완료되지 않았습니다."
        case .socialLoginCancelled:
            return nil
        case .emptyPasswordResetToken:
            return "재설정 토큰을 입력해주세요."
        case .passwordResetTokenInvalid:
            return "재설정 링크가 올바르지 않습니다. 다시 요청해주세요."
        case .passwordResetTokenExpired:
            return "재설정 링크가 만료되었습니다. 새 링크를 요청해주세요."
        case .passwordResetTokenUsed:
            return "이미 사용한 재설정 링크입니다. 새 링크를 요청해주세요."
        case .tokenExpired:
            return "세션이 만료되었습니다. 다시 로그인해주세요."
        case .unauthorized:
            return "인증이 필요합니다."
        case .validationFailed(let message):
            return message
        case .invalidEmailFormat:
            return "올바른 이메일 형식을 입력해주세요."
        case .passwordTooShort:
            return "비밀번호는 8자 이상이어야 합니다."
        case .passwordMismatch:
            return "비밀번호가 일치하지 않습니다."
        case .emptyNickname:
            return "닉네임을 입력해주세요."
        case .missingRefreshToken:
            return "저장된 세션이 없습니다."
        case .invalidResponse:
            return "서버 응답을 처리하지 못했습니다."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        case .server(_, let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}
