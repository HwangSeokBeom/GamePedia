import Foundation

enum AuthError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case emailAlreadyExists
    case accountDeletionUnavailable
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
        case "EMAIL_ALREADY_EXISTS":
            return .emailAlreadyExists
        case "ACCOUNT_DELETION_UNAVAILABLE":
            return .accountDeletionUnavailable
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
        case .accountDeletionUnavailable:
            return "현재 서버에서 회원 탈퇴를 지원하지 않습니다. 잠시 후 다시 시도해주세요."
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
