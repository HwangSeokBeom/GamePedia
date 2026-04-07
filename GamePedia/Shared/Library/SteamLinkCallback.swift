import Foundation

enum SteamLinkCallbackStatus: String {
    case success
    case failed
    case cancelled

    var logValue: String {
        rawValue
    }
}

struct SteamLinkCallbackResult: Equatable {
    let status: SteamLinkCallbackStatus
    let code: String?
    let message: String?
    let linked: Bool?

    var isSuccess: Bool {
        status == .success
    }

    var userFacingMessage: String? {
        switch status {
        case .success:
            return nil
        case .failed:
            return normalizedMessage
                ?? L10n.tr("Localizable", "library.steam.callback.failed")
        case .cancelled:
            return normalizedMessage ?? L10n.tr("Localizable", "library.steam.callback.cancelled")
        }
    }

    private var normalizedMessage: String? {
        guard let message else { return nil }
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMessage.isEmpty ? nil : trimmedMessage
    }
}

enum SteamLinkCallbackParser {
    static let callbackScheme = "gamepedia"
    private static let callbackHost = "steam"
    private static let callbackPath = "/callback"

    static func isSteamCallbackURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == callbackScheme else { return false }

        let normalizedHost = url.host?.lowercased()
        let normalizedPath = url.path.lowercased()
        if normalizedHost == callbackHost, normalizedPath == callbackPath {
            return true
        }

        let pathComponents = url.pathComponents
            .filter { $0 != "/" }
            .map { $0.lowercased() }

        return pathComponents == [callbackHost, "callback"]
    }

    static func parse(_ url: URL) -> SteamLinkCallbackResult? {
        guard isSteamCallbackURL(url) else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = MappingSafety.dictionary(
            pairs: (components?.queryItems ?? []).map { ($0.name.lowercased(), $0.value) },
            logPrefix: "[SteamLinkCallback]",
            keyName: "queryItem",
            countLabel: "queryCount",
            screen: "SteamLinkCallback.parse",
            mergePolicy: .keepFirst
        )

        let linked = parseBoolean(queryItems["linked"] ?? nil)
        let status = resolvedStatus(
            rawStatus: queryItems["status"] ?? nil,
            linked: linked,
            code: queryItems["code"] ?? nil,
            message: queryItems["message"] ?? nil
        )

        return SteamLinkCallbackResult(
            status: status,
            code: sanitized(queryItems["code"] ?? nil),
            message: sanitized(queryItems["message"] ?? nil),
            linked: linked
        )
    }

    private static func resolvedStatus(
        rawStatus: String?,
        linked: Bool?,
        code: String?,
        message: String?
    ) -> SteamLinkCallbackStatus {
        let normalizedStatus = sanitized(rawStatus)?.lowercased()
        switch normalizedStatus {
        case "success":
            return .success
        case "failed", "failure", "error":
            return .failed
        case "cancelled", "canceled", "cancel":
            return .cancelled
        case nil:
            if linked == true {
                return .success
            }
            if sanitized(code) != nil || sanitized(message) != nil {
                return .failed
            }
            return .failed
        default:
            return .failed
        }
    }

    private static func parseBoolean(_ value: String?) -> Bool? {
        guard let normalizedValue = sanitized(value)?.lowercased() else { return nil }

        switch normalizedValue {
        case "true", "1", "yes":
            return true
        case "false", "0", "no":
            return false
        default:
            return nil
        }
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
