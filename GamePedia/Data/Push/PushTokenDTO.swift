import Foundation

struct PushTokenRequestDTO: Encodable, Equatable {
    let token: String
    let platform: String
    let deviceId: String
    let appVersion: String
    let buildNumber: String
    let environment: String
}

struct PushTokenDeleteRequestDTO: Encodable, Equatable {
    let deviceId: String
    let platform: String
    let environment: String
}
