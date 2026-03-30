import Foundation

enum APIEnvironment: String, CaseIterable {
    case dev
    case staging
    case production

    var apiBaseURL: URL {
        switch self {
        case .dev:
            return URL(string: "http://127.0.0.1:3001")!
        case .staging:
            return URL(string: "https://staging-gamepedia-api.duckdns.org")!
        case .production:
            return URL(string: "https://gamepedia-api.duckdns.org")!
        }
    }

    var translationBaseURL: URL {
        switch self {
        case .dev:
            return URL(string: "http://127.0.0.1:3000")!
        case .staging:
            return URL(string: "https://staging-gamepedia-translate.duckdns.org")!
        case .production:
            return URL(string: "https://gamepedia-translate.duckdns.org")!
        }
    }
}

enum AppEnvironmentResolver {
    static var current: APIEnvironment {
        if let override = configuredOverride {
            return override
        }

#if DEBUG
        if let selectedEnvironment = DebugEnvironmentSelectionStore.selectedEnvironment {
            return selectedEnvironment
        }
#endif

        if isTestFlight {
            return .staging
        }

#if DEBUG
        return .staging
#else
        return .production
#endif
    }

    private static var configuredOverride: APIEnvironment? {
        if let environmentOverride = resolve(rawValue: ProcessInfo.processInfo.environment["API_ENVIRONMENT"]) {
            return environmentOverride
        }

        if let infoPlistOverride = resolve(rawValue: Bundle.main.object(forInfoDictionaryKey: "APIEnvironment") as? String) {
            return infoPlistOverride
        }

        return nil
    }

    private static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    private static func resolve(rawValue: String?) -> APIEnvironment? {
        guard let rawValue else { return nil }

        let normalizedValue = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedValue.isEmpty else { return nil }
        guard !normalizedValue.hasPrefix("$(") else { return nil }
        return APIEnvironment(rawValue: normalizedValue)
    }
}

#if DEBUG
enum DebugEnvironmentSelectionStore {
    private static let userDefaultsKey = "debugSelectedAPIEnvironment"
    private static let defaults = UserDefaults.standard

    static var selectedEnvironment: APIEnvironment? {
        get {
            guard let rawValue = defaults.string(forKey: userDefaultsKey) else { return nil }
            return APIEnvironment(rawValue: rawValue)
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: userDefaultsKey)
            } else {
                defaults.removeObject(forKey: userDefaultsKey)
            }
        }
    }
}
#endif
