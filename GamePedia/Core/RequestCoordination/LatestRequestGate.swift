import Foundation

// MARK: - LatestRequestGate
//
// Latest-request-wins identity, generalized from the `SearchViewModel`
// `activeSearchID` pattern. A view model begins a request to obtain a
// token; only the token from the most recent `begin()` may commit its
// result. Superseded and invalidated requests are rejected at commit
// time, so an older response can never overwrite newer state.
//
// MainActor-bound on purpose: tokens guard main-thread state mutation,
// and confining the gate makes begin/commit ordering deterministic
// without locks.

@MainActor
final class LatestRequestGate {

    struct Token: Equatable {
        fileprivate let id: UUID
    }

    private var activeID: UUID?

    /// True while a begun request has neither committed nor been invalidated.
    var hasActiveRequest: Bool {
        activeID != nil
    }

    /// Starts a new request generation, superseding any active one.
    func begin() -> Token {
        let token = Token(id: UUID())
        activeID = token.id
        return token
    }

    /// True only for the most recent uninvalidated `begin()` token.
    func isCurrent(_ token: Token) -> Bool {
        activeID == token.id
    }

    /// Commits the request: returns false (and changes nothing) unless
    /// `token` is current; otherwise ends the generation and returns true.
    /// Callers apply their state mutation only on `true`.
    func commit(_ token: Token) -> Bool {
        guard activeID == token.id else { return false }
        activeID = nil
        return true
    }

    /// Invalidates any active request; late commits then return false.
    func invalidate() {
        activeID = nil
    }
}
