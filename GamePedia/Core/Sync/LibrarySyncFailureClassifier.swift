import Foundation

// MARK: - Failure classification
//
// Maps transport errors onto the three retry classes. Classification is by
// stable `error.code` values and typed error cases only — never by localized
// message text.
//
// - permanent: deterministic validation rejections. Retrying the identical
//   payload can only fail identically, so the operation is dropped.
// - authRequired: the session cannot authorize right now. The queue pauses
//   and resumes on the next authenticated session event; retrying before
//   that would just burn attempts (and must never trigger its own refresh —
//   refresh ownership stays with the auth layer).
// - transient: everything reachability- or availability-shaped. Pending work
//   is preserved and retried with backoff.

enum LibrarySyncFailureClassifier {

    private static let permanentServerCodes: Set<String> = [
        "INVALID_GAME_ID",
        "INVALID_SOURCE_ID",
        "INVALID_EXTERNAL_GAME_ID",
        "INVALID_GAME_TITLE",
        "INVALID_STATUS",
        "INVALID_LIBRARY_SOURCE",
        "INVALID_LIBRARY_STATUS",
        "INVALID_COVER_URL",
        "INVALID_LIBRARY_DATE",
        "INVALID_PLAYTIME_MINUTES",
        "VALIDATION_ERROR",
        "VALIDATION_FAILED",
        "NOT_FOUND"
    ]

    private static let authServerCodes: Set<String> = [
        "UNAUTHORIZED",
        "TOKEN_EXPIRED",
        "TOKEN_REVOKED"
    ]

    static func classify(_ error: Error) -> LibrarySyncFailure {
        if let failure = error as? LibrarySyncFailure {
            return failure
        }

        if let favoriteError = error as? FavoriteError {
            switch favoriteError {
            case .unauthorized:
                return .authRequired(code: "UNAUTHORIZED")
            case .invalidGameId:
                return .permanent(code: "INVALID_GAME_ID")
            case .invalidSort:
                return .permanent(code: "INVALID_FAVORITE_SORT")
            case .validationFailed:
                return .permanent(code: "VALIDATION_ERROR")
            case .invalidResponse:
                return .permanent(code: "INVALID_RESPONSE")
            case .network:
                return .transient(code: "NETWORK")
            case .server(let code, _):
                return classifyServerCode(code)
            case .unknown:
                return .transient(code: "UNKNOWN")
            }
        }

        if let libraryError = error as? LibraryError {
            switch libraryError {
            case .unauthorized:
                return .authRequired(code: "UNAUTHORIZED")
            case .invalidGameIdentifier:
                return .permanent(code: "INVALID_GAME_ID")
            case .invalidStatus:
                return .permanent(code: "INVALID_STATUS")
            case .invalidResponse:
                return .permanent(code: "INVALID_RESPONSE")
            case .network:
                return .transient(code: "NETWORK")
            case .server(let code, _):
                return classifyServerCode(code)
            case .unknown:
                return .transient(code: "UNKNOWN")
            }
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return .authRequired(code: "UNAUTHORIZED")
            case .rateLimited:
                return .transient(code: "RATE_LIMITED")
            case .serverError(_, let code, _):
                return classifyServerCode(code ?? "SERVER_ERROR")
            case .invalidURL, .noData, .decodingFailed:
                return .permanent(code: "INVALID_RESPONSE")
            case .configurationMissing:
                return .permanent(code: "CONFIGURATION_MISSING")
            case .unknown:
                return .transient(code: "UNKNOWN")
            }
        }

        if error is URLError || error is CancellationError {
            return .transient(code: "NETWORK")
        }

        return .transient(code: "UNKNOWN")
    }

    private static func classifyServerCode(_ rawCode: String) -> LibrarySyncFailure {
        let code = rawCode.uppercased()
        if authServerCodes.contains(code) {
            return .authRequired(code: code)
        }
        if permanentServerCodes.contains(code) {
            return .permanent(code: code)
        }
        // Unrecognized server codes (5xx, RATE_LIMITED, CONFLICT, future
        // codes) stay transient: preserved and retried with backoff, bounded
        // by the automatic-attempt cap before parking for manual retry.
        return .transient(code: code)
    }
}
