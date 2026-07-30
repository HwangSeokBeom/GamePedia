import Foundation
import HTTPTypes
import OpenAPIRuntime

// MARK: - Product22JSON
//
// Reads and writes the contract's untyped JSON positions using plain Swift
// values, so a consumer never has to name an OpenAPIRuntime type.
//
// This is not sugar. Several contract fields are declared `{"type": "object"}`
// or as a bare `const` and the generator types them as `OpenAPIObjectContainer`
// / `OpenAPIValueContainer`. If the app touched those types directly it would
// have to import and link OpenAPIRuntime itself — which is precisely the
// transport dependency this package exists to contain. Keeping the surface
// here means the transport stays in one module by construction, not by
// convention.

/// The contract's untyped JSON positions, named so a consumer can write a
/// signature against them without importing OpenAPIRuntime.
public typealias Product22JSONValue = OpenAPIValueContainer
public typealias Product22JSONObject = OpenAPIObjectContainer

public enum Product22JSON {

    // MARK: Writing

    /// Builds a JSON object for a contract position the contract left untyped.
    public static func object(_ raw: [String: any Sendable]) throws -> Product22JSONObject {
        try OpenAPIObjectContainer(unvalidatedValue: raw)
    }

    /// Builds a single JSON value for a contract position typed as "any value".
    public static func value(_ raw: any Sendable) throws -> Product22JSONValue {
        try OpenAPIValueContainer(unvalidatedValue: raw)
    }

    // MARK: Reading

    /// The string behind a single-value `const` the generator typed as an
    /// opaque container. Four Today sections declare `status` that way.
    public static func string(_ container: Product22JSONValue) -> String? {
        container.value as? String
    }

    /// The boolean behind a `const: true` — `ownedOnly`, `deterministic`,
    /// `success`. Read rather than assumed, so a server that stops asserting
    /// the guarantee is noticed instead of papered over.
    public static func bool(_ container: Product22JSONValue) -> Bool? {
        container.value as? Bool
    }

    /// An array of strings at `key`, or nil if it is absent or shaped
    /// differently. Never throws and never partially succeeds: a mixed array
    /// yields nil rather than a silently filtered subset.
    public static func stringArray(
        _ container: Product22JSONObject,
        key: String
    ) -> [String]? {
        guard let raw = container.value[key], let items = raw as? [Any] else { return nil }
        let strings = items.compactMap { $0 as? String }
        guard strings.count == items.count else { return nil }
        return strings
    }
}

// MARK: - Product22ClientErrors

public enum Product22ClientErrors {
    /// Unwraps the runtime's `ClientError` so a caller can recover the error a
    /// middleware actually threw instead of a generic transport failure.
    /// Returns nil when `error` is not a client error.
    public static func underlyingError(of error: any Error) -> (any Error)? {
        (error as? ClientError)?.underlyingError
    }
}

// MARK: - BearerAuthorizationMiddleware
//
// Attaches — or refuses to attach — a bearer token.
//
// The middleware lives here, but the *policy* does not: the consumer supplies
// a resolver that runs at intercept time and decides. That keeps every
// credential rule (account binding, guest lockout, no refresh loop) in the
// app's session layer while the `ClientMiddleware` conformance, and the
// OpenAPIRuntime/HTTPTypes dependency it drags in, stay in this package.
//
// The resolver runs inside the same task as the operation call, so a task
// local set by the caller is visible to it.

public struct BearerAuthorizationMiddleware: ClientMiddleware {

    public enum Decision: Sendable {
        /// Attach `Authorization: Bearer <token>`.
        case attach(token: String)
        /// Send with no Authorization header at all.
        case omit
        /// Do not send. The error is thrown before the request is transmitted.
        case refuse(any Error)
    }

    private let resolve: @Sendable (String) -> Decision

    /// - Parameter resolve: called with the operationId for each request.
    public init(resolve: @escaping @Sendable (String) -> Decision) {
        self.resolve = resolve
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        switch resolve(operationID) {
        case .attach(let token):
            request.headerFields[.authorization] = "Bearer \(token)"
        case .omit:
            break
        case .refuse(let error):
            throw error
        }
        return try await next(request, body, baseURL)
    }
}
