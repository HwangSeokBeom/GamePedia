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
    static let appVersion = configuredString(
        infoPlistKey: "CFBundleShortVersionString",
        environmentKey: "APP_VERSION"
    ) ?? "unknown"
    static let buildNumber = configuredString(
        infoPlistKey: "CFBundleVersion",
        environmentKey: "APP_BUILD_NUMBER"
    ) ?? "unknown"
    static let buildSchemeName = configuredString(
        infoPlistKey: "BuildSchemeName",
        environmentKey: "BUILD_SCHEME_NAME"
    ) ?? "unknown"
    static let buildConfiguration = configuredString(
        infoPlistKey: "BuildConfiguration",
        environmentKey: "BUILD_CONFIGURATION"
    ) ?? "unknown"
    static let buildFlavor = configuredString(
        infoPlistKey: "BuildFlavor",
        environmentKey: "BUILD_FLAVOR_NAME"
    ) ?? apiEnvironment.rawValue
    static let coreBaseURL: URL = configuredURL(
        infoPlistKey: "CoreBaseURL",
        environmentKey: "CORE_BASE_URL",
        fallback: apiEnvironment.apiBaseURL
    )
    static let authBaseURL: URL = coreBaseURL
    static let googleClientID = oauthConfig.googleClientID
    static let googleReverseClientID = oauthConfig.googleReverseClientID
    static let termsOfServiceURL = configuredStaticURL(
        infoPlistKey: "TermsOfServiceURL",
        environmentKey: "TERMS_OF_SERVICE_URL",
        defaultValue: "https://hwangseokbeom.github.io/gamepedia-legal/terms.html"
    )
    static let privacyPolicyURL = configuredStaticURL(
        infoPlistKey: "PrivacyPolicyURL",
        environmentKey: "PRIVACY_POLICY_URL",
        defaultValue: "https://hwangseokbeom.github.io/gamepedia-legal/privacy.html"
    )
    static let communityGuidelinesURL = configuredStaticURL(
        infoPlistKey: "CommunityGuidelinesURL",
        environmentKey: "COMMUNITY_GUIDELINES_URL",
        defaultValue: "https://hwangseokbeom.github.io/gamepedia-legal/community.html"
    )
    static let supportEmail = configuredString(
        infoPlistKey: "SupportEmail",
        environmentKey: "SUPPORT_EMAIL"
    ) ?? "tjrqja0714@gmail.com"
    static let widgetAppGroupIdentifier = configuredString(
        infoPlistKey: "WidgetAppGroupIdentifier",
        environmentKey: "WIDGET_APP_GROUP_IDENTIFIER"
    )
    static let isTestFlightDistribution = AppEnvironmentResolver.isTestFlightDistribution
    static let distributionChannel = isTestFlightDistribution ? "testflight" : "local"
    static let apiHost = coreBaseURL.host ?? coreBaseURL.absoluteString
    static let buildTargetMessage = "THIS BUILD TARGETS \(apiEnvironment.rawValue.uppercased())"
    static let shouldShowBuildIndicator = apiEnvironment != .production || isTestFlightDistribution
    static let buildBadgeText = {
        let environmentLabel: String

        switch apiEnvironment {
        case .dev:
            environmentLabel = "DEV"
        case .staging:
            environmentLabel = "STAGING"
        case .production:
            environmentLabel = "PROD"
        }

        let channelSuffix = isTestFlightDistribution ? " TF" : ""
        return "\(environmentLabel)\(channelSuffix) \(appVersion)(\(buildNumber))"
    }()
    static let settingsBuildInfoText = [
        "Version: \(appVersion)",
        "Build: \(buildNumber)",
        "Scheme: \(buildSchemeName)",
        "Configuration: \(buildConfiguration)",
        "Flavor: \(buildFlavor)",
        "Environment: \(apiEnvironment.rawValue)",
        "Channel: \(distributionChannel)",
        "API Host: \(apiHost)",
        "API Base URL: \(coreBaseURL.absoluteString)"
    ].joined(separator: "\n")

    // MARK: - Presentation

    static let igdbImageSize = "t_cover_big"

    static let networkRuntimeDescription = {
#if targetEnvironment(simulator)
        "simulator"
#else
        "device"
#endif
    }()

    static func logRuntimeConfiguration() {
        print(
            "[BuildInfo] version=\(appVersion) build=\(buildNumber) " +
            "scheme=\(buildSchemeName) configuration=\(buildConfiguration) " +
            "flavor=\(buildFlavor) environment=\(apiEnvironment.rawValue) channel=\(distributionChannel)"
        )
        print("[BuildInfo] apiBaseURL=\(coreBaseURL.absoluteString)")
        print("[BuildInfo] \(buildTargetMessage)")
    }

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

    private static func configuredURL(
        infoPlistKey: String,
        environmentKey: String,
        fallback: URL
    ) -> URL {
        if let infoPlistValue = infoPlistString(for: infoPlistKey),
           let url = URL(string: infoPlistValue) {
            return url
        }

        if let environmentValue = sanitizedString(ProcessInfo.processInfo.environment[environmentKey]),
           let url = URL(string: environmentValue) {
            return url
        }

        return fallback
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
