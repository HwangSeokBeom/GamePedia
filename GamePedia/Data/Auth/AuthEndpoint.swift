import Foundation

enum AuthEndpoint {

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    case signUp(SignUpRequestDTO)
    case login(LoginRequestDTO)
    case refresh(RefreshRequestDTO)
    case logout(LogoutRequestDTO?)
    case currentUser
    case deleteAccount

    var path: String {
        switch self {
        case .signUp:
            return "auth/signup"
        case .login:
            return "auth/login"
        case .refresh:
            return "auth/refresh"
        case .logout:
            return "auth/logout"
        case .currentUser:
            return "auth/me"
        case .deleteAccount:
            return "auth/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .currentUser:
            return .get
        case .deleteAccount:
            return .delete
        case .signUp, .login, .refresh, .logout:
            return .post
        }
    }

    var requiresAuthorization: Bool {
        switch self {
        case .currentUser, .logout, .deleteAccount:
            return true
        case .signUp, .login, .refresh:
            return false
        }
    }

    func httpBody(using encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .signUp(let requestDTO):
            return try encoder.encode(requestDTO)
        case .login(let requestDTO):
            return try encoder.encode(requestDTO)
        case .refresh(let requestDTO):
            return try encoder.encode(requestDTO)
        case .logout(let requestDTO):
            guard let requestDTO else { return nil }
            return try encoder.encode(requestDTO)
        case .currentUser, .deleteAccount:
            return nil
        }
    }
}
