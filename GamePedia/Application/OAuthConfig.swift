import Foundation

struct OAuthConfig {
    let environment: APIEnvironment
    let callbackBaseURL: URL
    let googleClientID: String?
    let googleReverseClientID: String?

    var googleCallbackURL: URL {
        callbackBaseURL.appendingPathComponent("auth/google/callback")
    }

    var appleCallbackURL: URL {
        callbackBaseURL.appendingPathComponent("auth/apple/callback")
    }
}
