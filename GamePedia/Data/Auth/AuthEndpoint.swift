import Foundation

enum AuthEndpoint {

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    case signUp(SignUpRequestDTO)
    case login(LoginRequestDTO)
    case forgotPassword(ForgotPasswordRequestDTO)
    case resetPassword(ResetPasswordRequestDTO)
    case appleLogin(AppleLoginRequestDTO)
    case googleLogin(GoogleLoginRequestDTO)
    case refresh(RefreshRequestDTO)
    case logout(LogoutRequestDTO?)
    case currentUser
    case updateCurrentUserProfile(UpdateCurrentUserProfileRequestDTO)
    case uploadCurrentUserProfileImage(ProfileImageUploadRequestDTO)
    case removeCurrentUserProfileImage
    case deleteAccount

    var path: String {
        switch self {
        case .signUp:
            return "auth/signup"
        case .login:
            return "auth/login"
        case .forgotPassword:
            return "auth/forgot-password"
        case .resetPassword:
            return "auth/reset-password"
        case .appleLogin:
            return "auth/apple"
        case .googleLogin:
            return "auth/google"
        case .refresh:
            return "auth/refresh"
        case .logout:
            return "auth/logout"
        case .currentUser:
            return "auth/me"
        case .updateCurrentUserProfile:
            return "auth/me"
        case .uploadCurrentUserProfileImage:
            return "auth/me/profile-image"
        case .removeCurrentUserProfileImage:
            return "auth/me/profile-image"
        case .deleteAccount:
            return "auth/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .currentUser:
            return .get
        case .updateCurrentUserProfile, .uploadCurrentUserProfileImage:
            return .patch
        case .removeCurrentUserProfileImage, .deleteAccount:
            return .delete
        case .signUp, .login, .forgotPassword, .resetPassword, .appleLogin, .googleLogin, .refresh, .logout:
            return .post
        }
    }

    var requiresAuthorization: Bool {
        switch self {
        case .currentUser, .updateCurrentUserProfile, .uploadCurrentUserProfileImage, .removeCurrentUserProfileImage, .logout, .deleteAccount:
            return true
        case .signUp, .login, .forgotPassword, .resetPassword, .appleLogin, .googleLogin, .refresh:
            return false
        }
    }

    var contentType: String? {
        switch self {
        case .signUp, .login, .forgotPassword, .resetPassword, .appleLogin, .googleLogin, .refresh, .logout, .updateCurrentUserProfile:
            return "application/json"
        case .uploadCurrentUserProfileImage(let requestDTO):
            return requestDTO.contentType
        case .currentUser, .removeCurrentUserProfileImage, .deleteAccount:
            return nil
        }
    }

    func httpBody(using encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .signUp(let requestDTO):
            return try encoder.encode(requestDTO)
        case .login(let requestDTO):
            return try encoder.encode(requestDTO)
        case .forgotPassword(let requestDTO):
            return try encoder.encode(requestDTO)
        case .resetPassword(let requestDTO):
            return try encoder.encode(requestDTO)
        case .appleLogin(let requestDTO):
            return try encoder.encode(requestDTO)
        case .googleLogin(let requestDTO):
            return try encoder.encode(requestDTO)
        case .refresh(let requestDTO):
            return try encoder.encode(requestDTO)
        case .logout(let requestDTO):
            guard let requestDTO else { return nil }
            return try encoder.encode(requestDTO)
        case .updateCurrentUserProfile(let requestDTO):
            return try encoder.encode(requestDTO)
        case .uploadCurrentUserProfileImage(let requestDTO):
            return requestDTO.multipartBodyData()
        case .currentUser, .removeCurrentUserProfileImage, .deleteAccount:
            return nil
        }
    }
}
