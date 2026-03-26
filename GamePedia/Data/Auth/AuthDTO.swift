import Foundation

struct LoginRequestDTO: Encodable {
    let email: String
    let password: String
}

struct ForgotPasswordRequestDTO: Encodable {
    let email: String
}

struct ResetPasswordRequestDTO: Encodable {
    let token: String
    let newPassword: String
}

struct AppleLoginRequestDTO: Encodable {
    let identityToken: String
    let deviceName: String?
}

struct GoogleLoginRequestDTO: Encodable {
    let idToken: String
    let deviceName: String?
}

struct SignUpRequestDTO: Encodable {
    let email: String
    let password: String
    let nickname: String
}

struct RefreshRequestDTO: Encodable {
    let refreshToken: String
}

struct LogoutRequestDTO: Encodable {
    let refreshToken: String
}

struct AuthResponseDTO: Decodable {
    let success: Bool
    let data: AuthResponseDataDTO?
    let error: AuthErrorPayloadDTO?
}

struct AuthResponseDataDTO: Decodable {
    let user: UserDTO
    let tokens: TokenPairDTO?
}

struct AuthErrorPayloadDTO: Decodable {
    let code: String
    let message: String
}

struct ForgotPasswordResponseDataDTO: Decodable {
    let message: String
}

struct ResetPasswordResponseDataDTO: Decodable {
    let passwordReset: Bool
}

struct TokenPairDTO: Decodable {
    let accessToken: String
    let refreshToken: String
}

struct UserDTO: Decodable {
    let id: String
    let email: String
    let nickname: String
    let profileImageUrl: String?
    let status: String
    let createdAt: String
    let updatedAt: String
}

extension UserDTO {
    func toDomain() -> AuthUser {
        AuthUser(
            id: id,
            email: email,
            nickname: nickname,
            profileImageUrl: profileImageUrl,
            status: status
        )
    }
}

extension AuthResponseDTO {
    func toDomainSession() throws -> AuthSession {
        guard let data,
              let tokens = data.tokens else {
            throw AuthError.invalidResponse
        }

        return AuthSession(
            user: data.user.toDomain(),
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
        )
    }

    func toDomainUser() throws -> AuthUser {
        guard let data else {
            throw AuthError.invalidResponse
        }

        return data.user.toDomain()
    }
}
