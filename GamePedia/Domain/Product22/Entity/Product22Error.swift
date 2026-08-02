import Foundation

// MARK: - Product22Error
//
// The domain error every Product 2.2 call surfaces. Generated response types
// and transport errors stop here; nothing above the data layer sees an
// `Operations.…Output` or a `ClientError`.
//
// Two shapes matter beyond "it failed":
//
//   - `.unauthorized` is handed to the existing session lifecycle rather than
//     handled locally. This layer never refreshes a token and never retries a
//     request with a different credential.
//   - `.featureUnavailable` carries the server's kill-switch reason so the UI
//     can refresh product config and settle into a stable state instead of
//     showing a generic failure with a dead retry button.

enum Product22Error: Error, Equatable {

    /// 401. The session layer owns the response; this layer does nothing.
    case unauthorized

    /// 503 with `FEATURE_DISABLED` or `FEATURE_STATE_UNAVAILABLE`.
    case featureUnavailable(FeatureUnavailableReason)

    /// 400. Field errors are mapped to user-facing text by the presentation
    /// layer; the server's internal message is never shown raw.
    case validation(ValidationFailure)

    /// 404.
    case notFound

    /// 409.
    case conflict(code: String, message: String)

    /// 429.
    case rateLimited(code: String?, message: String?)

    /// The gesture's account no longer owns the session, detected before the
    /// request was transmitted. Never produced by the server.
    case accountChanged

    /// Any other non-2xx the contract does not describe.
    case server(statusCode: Int, code: String?, message: String?)

    /// URLSession/transport failure, including cancellation.
    case transport(message: String)

    /// The response did not match the contract.
    case decoding(message: String)

    /// True when the failure is the user (or the app) cancelling, which must
    /// never be rendered as an error.
    var isCancellation: Bool {
        if case .transport(let message) = self {
            return message == Self.cancellationMarker
        }
        return false
    }

    static let cancellationMarker = "cancelled"

    static var cancelled: Product22Error { .transport(message: cancellationMarker) }
}

// MARK: - FeatureUnavailableReason

enum FeatureUnavailableReason: Equatable, Sendable {
    /// The kill switch for this feature is off.
    case disabled
    /// The kill-switch table itself could not be read, so the server refuses
    /// every Product 2.2 endpoint. Pre-existing endpoints keep working.
    case stateUnavailable
    /// A 503 whose code the contract does not name.
    case other(code: String)

    init(code: String) {
        switch code {
        case "FEATURE_DISABLED": self = .disabled
        case "FEATURE_STATE_UNAVAILABLE": self = .stateUnavailable
        default: self = .other(code: code)
        }
    }

    var code: String {
        switch self {
        case .disabled: return "FEATURE_DISABLED"
        case .stateUnavailable: return "FEATURE_STATE_UNAVAILABLE"
        case .other(let code): return code
        }
    }
}

// MARK: - ValidationFailure

struct ValidationFailure: Equatable, Sendable {
    /// Server error code, e.g. `SUBMISSION_TITLE_REQUIRED`.
    let code: String
    /// Per-field problems, keyed by the field path the server named.
    let fieldErrors: [FieldError]

    struct FieldError: Equatable, Sendable {
        let field: String
        /// The server's raw message. Deliberately NOT displayed: server
        /// validation text leaks implementation detail (`unpaired surrogate`,
        /// Zod paths). The presentation layer maps `field` + `code` to
        /// localized copy and uses this only for diagnostics.
        let rawMessage: String
    }

    /// Whether the failure names a specific field the user can fix.
    func names(_ field: String) -> Bool {
        fieldErrors.contains { $0.field == field || $0.field.hasSuffix(".\(field)") }
    }
}

// MARK: - Known server error codes
//
// Only codes the app branches on. Anything else falls through to a generic
// stable state; the app never renders a code it does not understand.

enum Product22ErrorCode {
    static let featureDisabled = "FEATURE_DISABLED"
    static let featureStateUnavailable = "FEATURE_STATE_UNAVAILABLE"

    // Quick Add
    static let submissionTitleRequired = "SUBMISSION_TITLE_REQUIRED"
    static let submissionExpired = "SUBMISSION_EXPIRED"
    static let submissionAlreadyConfirmed = "SUBMISSION_ALREADY_CONFIRMED"
    static let submissionQuotaExceeded = "SUBMISSION_QUOTA_EXCEEDED"
    static let identityConflict = "CATALOG_IDENTITY_CONFLICT"

    // Playlog
    static let playSessionConflict = "PLAY_SESSION_CONFLICT"
}
