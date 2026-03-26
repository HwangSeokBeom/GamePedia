import Foundation

struct AuthSession: Equatable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
}
