import Foundation
import GamePediaProduct22API
import OpenAPIRuntime

// MARK: - Product22ErrorMapper
//
// Turns the generated response cases and transport failures into
// `Product22Error`. Every Product 2.2 call funnels through here so the error
// vocabulary above the data layer stays small and the 401/503 policies are
// written once.

enum Product22ErrorMapper {

    // MARK: Envelope → domain

    static func validation(_ envelope: Components.Schemas.ErrorEnvelope) -> Product22Error {
        .validation(
            ValidationFailure(
                code: envelope.error.code,
                fieldErrors: (envelope.error.details ?? []).compactMap { detail in
                    guard let field = detail.field else { return nil }
                    return ValidationFailure.FieldError(
                        field: field,
                        rawMessage: detail.message ?? ""
                    )
                }
            )
        )
    }

    static func featureUnavailable(_ envelope: Components.Schemas.ErrorEnvelope) -> Product22Error {
        .featureUnavailable(FeatureUnavailableReason(code: envelope.error.code))
    }

    static func conflict(_ envelope: Components.Schemas.ErrorEnvelope) -> Product22Error {
        .conflict(code: envelope.error.code, message: envelope.error.message)
    }

    static func rateLimited(_ envelope: Components.Schemas.ErrorEnvelope) -> Product22Error {
        .rateLimited(code: envelope.error.code, message: envelope.error.message)
    }

    static func undocumented(statusCode: Int) -> Product22Error {
        switch statusCode {
        case 401: return .unauthorized
        case 404: return .notFound
        default: return .server(statusCode: statusCode, code: nil, message: nil)
        }
    }

    // MARK: Thrown errors → domain
    //
    // A middleware throwing `Product22Error` (account changed, guest-only)
    // arrives here wrapped in the runtime's `ClientError`; unwrapping it keeps
    // the precise reason instead of degrading it to a generic transport
    // failure. Cancellation is likewise preserved so the UI can stay silent.

    static func map(_ error: any Error) -> Product22Error {
        if let mapped = error as? Product22Error { return mapped }

        if let clientError = error as? ClientError {
            return map(clientError.underlyingError)
        }

        if error is CancellationError { return .cancelled }

        if let urlError = error as? URLError {
            if urlError.code == .cancelled { return .cancelled }
            return .transport(message: urlError.localizedDescription)
        }

        if let decodingError = error as? DecodingError {
            return .decoding(message: describe(decodingError))
        }

        return .transport(message: String(describing: type(of: error)))
    }

    /// Describes a decoding failure structurally. The failing *value* is never
    /// included: a decoding error can be raised on a field holding a Playlog
    /// note or an article body, and this string reaches the logs.
    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case .typeMismatch(let type, let context):
            return "typeMismatch(\(type)) at \(path(context))"
        case .valueNotFound(let type, let context):
            return "valueNotFound(\(type)) at \(path(context))"
        case .keyNotFound(let key, let context):
            return "keyNotFound(\(key.stringValue)) at \(path(context))"
        case .dataCorrupted(let context):
            return "dataCorrupted at \(path(context))"
        @unknown default:
            return "unknownDecodingError"
        }
    }
}
