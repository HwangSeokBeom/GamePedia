import Foundation

// MARK: - AppConfig
// Single source of truth for all credentials and base URLs.
// TODO: Before shipping — move twitchClientSecret out of source code.
//       Options: xcconfig + .gitignore, or fetch from a secure remote config.

enum AppConfig {

    // MARK: - Twitch / IGDB Credentials
    // TODO: Replace with your actual credentials before shipping
    static let twitchClientID     = "w3o7azrujjtery8dh9re2v9jp815pb"
    static let twitchClientSecret = "f45lcjhqkql3xtxak2cw832fyyw4qj"

    // MARK: - Base URLs
    static let igdbBaseURL        = URL(string: "https://api.igdb.com/v4")!
    static let twitchTokenURL     = URL(string: "https://id.twitch.tv/oauth2/token")!
    // Before TestFlight / App Review, replace localhost with a device-reachable backend URL.
    static let authBaseURL        = configuredURL(
        infoPlistKey: "AuthBaseURL",
        environmentKey: "AUTH_BASE_URL",
        defaultValue: "http://localhost:3001"
    )
    // On a real device, localhost points at the iPhone itself, not this Mac.
    static let translationBaseURL = configuredURL(
        infoPlistKey: "TranslationBaseURL",
        environmentKey: "TRANSLATION_BASE_URL",
        defaultValue: "http://localhost:3000"
    )

    // MARK: - IGDB Image
    // Replace t_thumb with any IGDB image size slug.
    // Available sizes: t_thumb, t_cover_small, t_cover_big, t_720p, t_1080p
    static let igdbImageSize      = "t_cover_big"

    private static func configuredURL(
        infoPlistKey: String,
        environmentKey: String,
        defaultValue: String
    ) -> URL {
        let infoPlistValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String
        let environmentValue = ProcessInfo.processInfo.environment[environmentKey]

        if infoPlistKey == "TranslationBaseURL" {
            print("[AppConfig] TranslationBaseURL plist=\(infoPlistValue ?? "nil")")
            print("[AppConfig] TRANSLATION_BASE_URL env=\(environmentValue ?? "nil")")
        }

        if let value = infoPlistValue,
           let url = URL(string: value) {
            if infoPlistKey == "TranslationBaseURL" {
                print("[AppConfig] translationBaseURL=\(url.absoluteString) source=Info.plist")
            }
            return url
        }

        if let value = environmentValue,
           let url = URL(string: value) {
            if infoPlistKey == "TranslationBaseURL" {
                print("[AppConfig] translationBaseURL=\(url.absoluteString) source=environment")
            }
            return url
        }

        let fallbackURL = URL(string: defaultValue)!
        if infoPlistKey == "TranslationBaseURL" {
            print("[AppConfig] translationBaseURL=\(fallbackURL.absoluteString) source=default")
        }
        return fallbackURL
    }
}
