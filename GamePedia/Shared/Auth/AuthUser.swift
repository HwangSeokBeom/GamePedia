import Foundation

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let nickname: String
    let profileImageUrl: String?
    let status: String
}
