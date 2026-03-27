import Foundation

struct OAuthConfig {
    let environment: APIEnvironment
    let googleClientID: String?
    let googleReverseClientID: String?

    var callbackBaseURL: URL {
        environment.apiBaseURL
    }

    var googleCallbackURL: URL {
        callbackBaseURL.appendingPathComponent("auth/google/callback")
    }

    var appleCallbackURL: URL {
        callbackBaseURL.appendingPathComponent("auth/apple/callback")
    }
}
