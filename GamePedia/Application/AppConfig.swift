import Foundation

// MARK: - AppConfig
// Single source of truth for runtime configuration.
// Server-side secrets must never be embedded in the iOS client.

enum AppConfig {

    // MARK: - Public Configuration

    static let apiEnvironment = AppEnvironmentResolver.current
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
        environmentKey: "BUILD_SCHEME_NAME",
        preferEnvironment: true
    ) ?? "unknown"
    static let buildConfiguration = configuredString(
        infoPlistKey: "BuildConfiguration",
        environmentKey: "BUILD_CONFIGURATION"
    ) ?? "unknown"
    static let buildFlavor = configuredString(
        infoPlistKey: "BuildFlavor",
        environmentKey: "BUILD_FLAVOR_NAME"
    ) ?? apiEnvironment.rawValue
    static let isTestFlightDistribution = AppEnvironmentResolver.isTestFlightDistribution
    static let distributionChannel = configuredString(
        infoPlistKey: "DistributionChannel",
        environmentKey: "DISTRIBUTION_CHANNEL",
        preferEnvironment: true
    ) ?? (isTestFlightDistribution ? "testflight" : "local")
    private static let coreBaseURLResolution = resolvedCoreBaseURL()
    static let coreBaseURL: URL = coreBaseURLResolution.url
    static let coreBaseURLSource = coreBaseURLResolution.source
    static let authBaseURL: URL = coreBaseURL
    static let oauthConfig = OAuthConfig(
        environment: apiEnvironment,
        callbackBaseURL: coreBaseURL,
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
        "API Base URL: \(coreBaseURL.absoluteString)",
        "API Base URL Source: \(coreBaseURLSource)"
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
        print(
            "[BuildInfo] scheme=\(buildSchemeName) configuration=\(buildConfiguration) " +
            "flavor=\(buildFlavor) environment=\(apiEnvironment.rawValue) " +
            "channel=\(distributionChannel) runtime=\(networkRuntimeDescription) " +
            "apiBaseURL=\(coreBaseURL.absoluteString) source=\(coreBaseURLSource)"
        )
        print("[BuildInfo] apiBaseURL=\(coreBaseURL.absoluteString)")
        print("[BuildInfo] \(buildTargetMessage)")
    }

    // MARK: - Private

    private struct URLResolution {
        let url: URL
        let source: String
    }

    private static func configuredString(
        infoPlistKey: String,
        environmentKey: String,
        preferEnvironment: Bool = false
    ) -> String? {
        if preferEnvironment,
           let environmentValue = sanitizedString(ProcessInfo.processInfo.environment[environmentKey]) {
            return environmentValue
        }

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
        configuredURLWithSource(
            infoPlistKey: infoPlistKey,
            environmentKey: environmentKey,
            fallback: fallback,
            fallbackSource: "APIEnvironment.\(apiEnvironment.rawValue)"
        ).url
    }

    private static func configuredURLWithSource(
        infoPlistKey: String,
        environmentKey: String,
        fallback: URL,
        fallbackSource: String,
        preferEnvironment: Bool = false
    ) -> URLResolution {
        if preferEnvironment,
           let environmentValue = sanitizedString(ProcessInfo.processInfo.environment[environmentKey]),
           let url = URL(string: environmentValue) {
            return URLResolution(url: url, source: environmentKey)
        }

        if let infoPlistValue = infoPlistString(for: infoPlistKey),
           let url = URL(string: infoPlistValue) {
            return URLResolution(url: url, source: environmentKey)
        }

        if let environmentValue = sanitizedString(ProcessInfo.processInfo.environment[environmentKey]),
           let url = URL(string: environmentValue) {
            return URLResolution(url: url, source: environmentKey)
        }

        return URLResolution(url: fallback, source: fallbackSource)
    }

    private static func resolvedCoreBaseURL() -> URLResolution {
        let configuredCoreURL = configuredURLWithSource(
            infoPlistKey: "CoreBaseURL",
            environmentKey: "CORE_BASE_URL",
            fallback: apiEnvironment.apiBaseURL,
            fallbackSource: "APIEnvironment.\(apiEnvironment.rawValue)"
        )

        let resolvedURL: URLResolution

        if isDeviceDevChannel,
           let deviceDevURL = configuredDeviceDevBaseURL() {
            resolvedURL = deviceDevURL
        } else if isPhysicalDeviceRuntime,
                  apiEnvironment == .dev,
                  isLoopbackURL(configuredCoreURL.url),
                  let deviceDevURL = configuredDeviceDevBaseURL() {
            print(
                "[ConfigurationWarning] runtime=device resolved loopback apiBaseURL=" +
                "\(configuredCoreURL.url.absoluteString); using DEV_DEVICE_API_BASE_URL=" +
                "\(deviceDevURL.url.absoluteString). 127.0.0.1/localhost on a real device points to the iPhone, not the Mac."
            )
            resolvedURL = deviceDevURL
        } else {
            if isPhysicalDeviceRuntime, isLoopbackURL(configuredCoreURL.url) {
                print(
                    "[ConfigurationWarning] runtime=device apiBaseURL=\(configuredCoreURL.url.absoluteString). " +
                    "127.0.0.1/localhost on a real device points to the iPhone, not the Mac."
                )
            }
            resolvedURL = configuredCoreURL
        }

        validateProductionURL(resolvedURL.url)
        return resolvedURL
    }

    private static func configuredDeviceDevBaseURL() -> URLResolution? {
        let placeholderFallback = URL(string: "http://127.0.0.1:3001")!
        let resolution = configuredURLWithSource(
            infoPlistKey: "DevDeviceAPIBaseURL",
            environmentKey: "DEV_DEVICE_API_BASE_URL",
            fallback: placeholderFallback,
            fallbackSource: "DEV_DEVICE_API_BASE_URL",
            preferEnvironment: true
        )

        guard !isLoopbackURL(resolution.url) else { return nil }
        return resolution
    }

    private static var isDeviceDevChannel: Bool {
        buildSchemeName == "GamePedia-DeviceDev" || distributionChannel == "deviceDev"
    }

    private static var isPhysicalDeviceRuntime: Bool {
#if targetEnvironment(simulator)
        false
#else
        true
#endif
    }

    private static func validateProductionURL(_ url: URL) {
        guard apiEnvironment == .production || buildConfiguration == "Release" else { return }

        if isLoopbackURL(url) || isPrivateNetworkURL(url) || url.scheme?.lowercased() == "http" {
            fatalError(
                "[ConfigurationError] Release/production builds must not use local HTTP API URLs. " +
                "configuration=\(buildConfiguration) environment=\(apiEnvironment.rawValue) apiBaseURL=\(url.absoluteString)"
            )
        }
    }

    private static func isLoopbackURL(_ url: URL) -> Bool {
        guard let host = normalizedHost(for: url) else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    private static func isPrivateNetworkURL(_ url: URL) -> Bool {
        guard let host = normalizedHost(for: url) else { return false }
        guard !isLoopbackURL(url) else { return true }

        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else {
            return host.hasSuffix(".local")
        }

        switch octets[0] {
        case 10:
            return true
        case 172:
            return (16...31).contains(octets[1])
        case 192:
            return octets[1] == 168
        case 169:
            return octets[1] == 254
        default:
            return false
        }
    }

    private static func normalizedHost(for url: URL) -> String? {
        url.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
