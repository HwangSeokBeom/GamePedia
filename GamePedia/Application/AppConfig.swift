import Foundation

// MARK: - AppConfig
// Single source of truth for runtime configuration.
// Server-side secrets must never be embedded in the iOS client.

enum AppConfig {

    // MARK: - Public Configuration

    static let apiEnvironment = AppEnvironmentResolver.current
    static let oauthConfig = OAuthConfig(
        environment: apiEnvironment,
        googleClientID: configuredString(
            infoPlistKey: "GIDClientID",
            environmentKey: "GOOGLE_CLIENT_ID"
        ),
        googleReverseClientID: configuredString(
            infoPlistKey: "GoogleReverseClientID",
            environmentKey: "GOOGLE_REVERSED_CLIENT_ID"
        ) ?? firstGoogleURLScheme()
    )
    static let featureFlags = FeatureFlags.defaults(for: apiEnvironment)
    static let authBaseURL: URL = {
        let environment = AppEnvironmentResolver.current
        let baseURL = environment.apiBaseURL
        print("[AppConfig] APIEnvironment=\(environment.rawValue) authBaseURL=\(baseURL.absoluteString)")
        return baseURL
    }()
    static let translationBaseURL: URL = {
        let environment = AppEnvironmentResolver.current
        let baseURL = environment.translationBaseURL
        print("[AppConfig] APIEnvironment=\(environment.rawValue) translationBaseURL=\(baseURL.absoluteString)")
        return baseURL
    }()
    static let googleClientID = oauthConfig.googleClientID
    static let googleReverseClientID = oauthConfig.googleReverseClientID
    static let termsOfServiceURL = configuredStaticURL(
        infoPlistKey: "TermsOfServiceURL",
        environmentKey: "TERMS_OF_SERVICE_URL",
        defaultValue: "https://example.com/gamepedia/terms"
    )
    static let privacyPolicyURL = configuredStaticURL(
        infoPlistKey: "PrivacyPolicyURL",
        environmentKey: "PRIVACY_POLICY_URL",
        defaultValue: "https://example.com/gamepedia/privacy"
    )
    static let communityGuidelinesURL = configuredStaticURL(
        infoPlistKey: "CommunityGuidelinesURL",
        environmentKey: "COMMUNITY_GUIDELINES_URL",
        defaultValue: "https://example.com/gamepedia/community-guidelines"
    )
    static let supportEmail = configuredString(
        infoPlistKey: "SupportEmail",
        environmentKey: "SUPPORT_EMAIL"
    ) ?? "support@gamepedia.app"

    // MARK: - Presentation

    static let igdbImageSize = "t_cover_big"

    static let networkRuntimeDescription = {
#if targetEnvironment(simulator)
        "simulator"
#else
        "device"
#endif
    }()

    // MARK: - Private

    private static func configuredString(
        infoPlistKey: String,
        environmentKey: String
    ) -> String? {
        if let infoPlistValue = infoPlistString(for: infoPlistKey) {
            return infoPlistValue
        }

        if let environmentValue = sanitizedString(ProcessInfo.processInfo.environment[environmentKey]) {
            return environmentValue
        }

        return nil
    }

    private static func configuredStaticURL(
        infoPlistKey: String,
        environmentKey: String,
        defaultValue: String
    ) -> URL {
        if let infoPlistValue = infoPlistString(for: infoPlistKey),
           let url = URL(string: infoPlistValue) {
            return url
        }

        if let environmentValue = sanitizedString(ProcessInfo.processInfo.environment[environmentKey]),
           let url = URL(string: environmentValue) {
            return url
        }

        return URL(string: defaultValue)!
    }

    private static func infoPlistString(for key: String) -> String? {
        sanitizedString(Bundle.main.object(forInfoDictionaryKey: key) as? String)
    }

    private static func firstGoogleURLScheme() -> String? {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }

        return urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
            .first { $0.hasPrefix("com.googleusercontent.apps.") }
    }

    private static func sanitizedString(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        guard !trimmedValue.hasPrefix("$(") else { return nil }
        guard !trimmedValue.hasPrefix("YOUR_") else { return nil }
        return trimmedValue
    }
}
