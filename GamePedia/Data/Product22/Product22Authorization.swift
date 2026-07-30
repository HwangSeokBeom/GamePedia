import Foundation
import GamePediaProduct22API

// MARK: - Product22Authorization
//
// How one Product 2.2 request resolves its credential. Mirrors the existing
// `RequestAuthorization` used by `APIClient` so both networking paths obey the
// same account-binding rules; it is a separate type only because the generated
// client reaches the credential through a middleware rather than through
// `APIClient.buildRequest`.

enum Product22Authorization: Equatable, Sendable {

    /// Anonymous. No Authorization header is attached, ever.
    ///
    /// The Product 2.2 contract declares `bearerAuth` globally and the server
    /// puts `authenticateAccessToken` on every route, so no operation is
    /// anonymous today. The case exists so that a future public operation is
    /// expressed rather than accidentally authenticated, and so tests can
    /// assert that nothing forces a header on.
    case anonymous

    /// Reads the current session credential when the request is built. For
    /// reads, which are not account-critical: a read issued across a session
    /// change is discarded by the repository rather than displayed.
    case currentSession

    /// Atomic bind against a gesture-time account expectation. Every mutation
    /// started by a user gesture uses this: if the account was replaced,
    /// logged out or deleted since the gesture, the request fails before
    /// transmission instead of being sent with somebody else's token.
    case boundAccount(AuthorizationExpectation)

    /// A gesture that a guest started. It must never acquire a bearer token,
    /// not even one that appeared after the gesture, so it fails closed.
    case guestOnly
}

// MARK: - Product22AuthorizationContext
//
// The generated client takes its middlewares at construction time, but the
// authorization mode is a property of the *call*, not of the client. A task
// local carries the mode from the call site to the middleware: the middleware
// runs inside the same task as the `await` on the operation, so it inherits
// the value. This keeps one client instance while still letting each call
// declare its own credential rules.

enum Product22AuthorizationContext {
    @TaskLocal static var current: Product22Authorization = .anonymous

    static func withAuthorization<T>(
        _ authorization: Product22Authorization,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await $current.withValue(authorization, operation: operation)
    }
}

// MARK: - Product22AuthorizationPolicy
//
// The credential rules, as a plain function of (authorization, authority).
//
// The `ClientMiddleware` conformance itself lives in the API package so the
// app never links OpenAPIRuntime or HTTPTypes; this type supplies the policy
// the package's middleware calls into.
//
// What it deliberately does NOT do:
//   - refresh a token (the existing auth layer owns refresh; a second refresh
//     loop would race it and could hand two accounts' tokens to one request)
//   - retry anything
//   - read the mutable current token for an account-bound request

enum Product22AuthorizationPolicy {

    static func decide(
        _ authorization: Product22Authorization,
        authority: SessionCredentialAuthority
    ) -> BearerAuthorizationMiddleware.Decision {
        switch authorization {
        case .anonymous:
            // Nothing attached. Not even if a session exists.
            return .omit

        case .currentSession:
            guard let token = authority.currentAccessToken else {
                return .refuse(Product22Error.unauthorized)
            }
            return .attach(token: token)

        case .boundAccount(let expectation):
            // Ownership validation and credential snapshot happen under one
            // lock inside the authority, so nothing can slip between them.
            guard let snapshot = authority.bindCredential(expectation: expectation) else {
                return .refuse(Product22Error.accountChanged)
            }
            return .attach(token: snapshot.accessToken)

        case .guestOnly:
            // Deterministic refusal, no networking. A guest gesture can never
            // mutate an account that logged in after the gesture.
            return .refuse(Product22Error.unauthorized)
        }
    }

    /// The middleware the client is built with. It reads the task local at
    /// intercept time, so one client serves every authorization mode.
    static func makeMiddleware(
        authority: SessionCredentialAuthority
    ) -> BearerAuthorizationMiddleware {
        BearerAuthorizationMiddleware { _ in
            decide(Product22AuthorizationContext.current, authority: authority)
        }
    }
}
