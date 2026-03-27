import Foundation

// MARK: - AppConfig
// Single source of truth for runtime configuration.
// Server-side secrets must never be embedded in the iOS client.

enum AppConfig {

    // MARK: - Public Configuration

    static let apiEnvironment = APIEnvironment.current
    static let authBaseURL: URL = {
        let environment = APIEnvironment.current
        let baseURL = environment.baseURL
        print("[AppConfig] APIEnvironment=\(environment.rawValue) authBaseURL=\(baseURL.absoluteString)")
        return baseURL
    }()
    static let translationBaseURL = configuredDevelopmentURL(
        infoPlistKey: "TranslationBaseURL",
        environmentKey: "TRANSLATION_BASE_URL",
        defaultPort: 3000
    )
    static let googleClientID = infoPlistString(for: "GIDClientID")
        ?? configuredString(
            infoPlistKey: "GoogleClientID",
            environmentKey: "GOOGLE_CLIENT_ID"
        )
    static let googleReverseClientID = configuredString(
        infoPlistKey: "GoogleReverseClientID",
        environmentKey: "GOOGLE_REVERSED_CLIENT_ID"
    ) ?? firstGoogleURLScheme()
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

    private static let localDevelopmentServerHost = configuredString(
        infoPlistKey: "LocalDevelopmentServerHost",
        environmentKey: "LOCAL_DEVELOPMENT_SERVER_HOST"
    ) ?? "localhost"

    // MARK: - Private

    private static func configuredDevelopmentURL(
        infoPlistKey: String,
        environmentKey: String,
        defaultPort: Int
    ) -> URL {
        let infoPlistValue = infoPlistString(for: infoPlistKey)
        let environmentValue = ProcessInfo.processInfo.environment[environmentKey]

        if let url = resolvedConfiguredURL(
            value: infoPlistValue,
            source: "Info.plist",
            configKey: infoPlistKey
        ) {
            return url
        }

        if let url = resolvedConfiguredURL(
            value: environmentValue,
            source: "environment",
            configKey: infoPlistKey
        ) {
            return url
        }

        let fallbackHost = defaultDevelopmentHost
        let fallbackURL = URL(string: "http://\(fallbackHost):\(defaultPort)")!
        print("[AppConfig] \(infoPlistKey)=\(fallbackURL.absoluteString) source=default runtime=\(networkRuntimeDescription)")
        return fallbackURL
    }

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

    private static var defaultDevelopmentHost: String {
#if targetEnvironment(simulator)
        return "localhost"
#else
        return localDevelopmentServerHost
#endif
    }

    private static func resolvedConfiguredURL(
        value: String?,
        source: String,
        configKey: String
    ) -> URL? {
        guard let value = sanitizedString(value),
              let url = URL(string: value) else {
            return nil
        }

        if shouldIgnoreLoopbackURL(url) {
            print("[AppConfig] \(configKey)=\(url.absoluteString) source=\(source) ignored on device because loopback URLs cannot reach the Mac-hosted server")
            return nil
        }

        print("[AppConfig] \(configKey)=\(url.absoluteString) source=\(source) runtime=\(networkRuntimeDescription)")
        return url
    }

    private static func shouldIgnoreLoopbackURL(_ url: URL) -> Bool {
        guard networkRuntimeDescription == "device" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
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
