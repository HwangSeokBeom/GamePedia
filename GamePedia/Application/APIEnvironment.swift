import Foundation

enum APIEnvironment: String, CaseIterable {
    case dev
    case staging
    case production

    var baseURL: URL {
        switch self {
        case .dev:
            return URL(string: "http://localhost:3001")!
        case .staging:
            return URL(string: "https://staging-gamepedia-api.duckdns.org")!
        case .production:
            return URL(string: "https://gamepedia-api.duckdns.org")!
        }
    }

    static var current: APIEnvironment {
        if let override = configuredOverride {
            return override
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
