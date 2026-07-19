import Foundation

// MARK: - Atomic session→credential binding (iOS 2.4 review follow-up)
//
// Authenticated favorite/library mutations used to validate account
// ownership in one place (the sync engine) and then read the MUTABLE
// current access token in another (`APIClient.userAuthToken`) when the
// request was finally built. Between those two reads the session can change,
// so an operation validated for account A could transmit with account B's
// token.
//
// This authority makes the two steps one atomic operation at the
// auth/network boundary:
//
//   1. validate the expected account/session ownership
//   2. snapshot the credential belonging to that same account/session
//   3. hand the snapshot to request construction
//
// All three happen under one lock (`bindCredential`), so a request either
// binds to the expected account's currently valid credential or fails
// before transmission. It can never read another account's token after
// validating the expected one.
//
// Session-epoch semantics mirror the account-scope semantics used by the
// sync engine and the gesture-time ownership context:
//
// - the epoch advances on every account-scope transition: first login,
//   account replacement (A → B), logout, account deletion. A → B → A
//   advances it twice, so an expectation captured under the first A session
//   can never bind again ("ids are never reused" in time).
// - a same-account credential refresh (same account ID re-adopted) swaps
//   the stored token WITHOUT advancing the epoch: an existing expectation
//   stays valid and binds the refreshed token. Refresh ownership stays with
//   the auth layer's single-flight mechanism — this type never refreshes.
//
// The authority stores at most one live (account, token) pair — exactly the
// state `APIClient.userAuthToken` used to hold — and hands out:
//
// - `AuthorizationExpectation`: identifiers only (account ID + epoch),
//   never credential material. Safe to hold across suspensions.
// - `AuthorizationCredentialSnapshot`: the short-lived bind result used
//   for exactly one request construction. Never persisted, never logged.

/// The expected account/session ownership of an operation. Identifiers
/// only — an expectation must never store an access or refresh token.
struct AuthorizationExpectation: Equatable, Sendable {
    /// Account the operation belongs to.
    let accountID: String
    /// Session epoch under which the expectation was captured. Any
    /// account-scope transition (replacement, logout, deletion, A → B → A)
    /// advances the epoch and permanently invalidates the expectation; a
    /// same-account credential refresh preserves it.
    let sessionEpoch: UInt64
}

/// Short-lived result of one successful atomic bind: the credential that
/// belonged to the expected account/session at bind time. Used for exactly
/// one request construction and then discarded — never stored, persisted,
/// or logged.
struct AuthorizationCredentialSnapshot: Equatable, Sendable {
    let accountID: String
    let sessionEpoch: UInt64
    let accessToken: String
}

/// How a request resolves its Authorization credential. Favorite/library
/// mutations must never use `.currentSession`; see each case.
enum RequestAuthorization: Equatable, Sendable {
    /// Legacy behavior: read the mutable current-session token when the
    /// request is built. Reads and endpoints that are not account-critical
    /// mutations keep this; it is also the explicit kill-switch path
    /// (`LibrarySyncRuntime` disabled), which is compile-time unreachable
    /// while `FeatureFlags.enableOfflineLibrarySync` is true.
    case currentSession
    /// Atomic bind: validate `expectation` and snapshot its account's
    /// credential under one lock, or fail before transmission. The only
    /// authorization the sync engine's remote execution uses.
    case boundAccount(AuthorizationExpectation)
    /// Explicitly unauthenticated: the request must not be able to obtain
    /// an authenticated bearer token. For endpoints that require user auth
    /// this fails before transmission unconditionally — a guest gesture can
    /// therefore never mutate an account that logged in after the gesture.
    case guestOnly
}

/// Lock-based (never actor-isolated) so validation + snapshot + request
/// construction stay synchronous at the network boundary.
final class SessionCredentialAuthority: @unchecked Sendable {

    private let lock = NSLock()
    private var accountID: String?
    private var accessToken: String?
    private var sessionEpoch: UInt64 = 0

    /// Adopts an authenticated session. Same account ID → same-account
    /// credential refresh: the token is swapped and the epoch (and with it
    /// every outstanding expectation) is preserved. Different account ID →
    /// account replacement: the epoch advances and every expectation
    /// captured before it becomes permanently unbindable.
    func adoptAuthenticatedSession(accountID: String, accessToken: String) {
        lock.lock()
        defer { lock.unlock() }
        if self.accountID != accountID {
            sessionEpoch &+= 1
            self.accountID = accountID
        }
        self.accessToken = accessToken
    }

    /// Logout / account deletion / refresh failure: no session owns the
    /// credential slot any more. Advances the epoch so an A → (cleared) → A
    /// round trip yields a new epoch and old expectations stay dead.
    func clearSession() {
        lock.lock()
        defer { lock.unlock() }
        guard accountID != nil || accessToken != nil else { return }
        sessionEpoch &+= 1
        accountID = nil
        accessToken = nil
    }

    /// Legacy seam preserving the old `APIClient.userAuthToken` setter
    /// contract (tests and diagnostics): a raw token write without account
    /// identity. It keeps `.currentSession` requests working but can never
    /// satisfy an account-bound expectation on its own.
    func adoptLegacyAccessToken(_ token: String?) {
        guard let token else {
            clearSession()
            return
        }
        lock.lock()
        defer { lock.unlock() }
        accessToken = token
    }

    /// Mutable current-session token (`.currentSession` requests and the
    /// existing `userAuthToken` read sites).
    var currentAccessToken: String? {
        lock.lock()
        defer { lock.unlock() }
        return accessToken
    }

    /// Currently owning account, if any (diagnostics/tests).
    var currentAccountID: String? {
        lock.lock()
        defer { lock.unlock() }
        return accountID
    }

    /// Captures the expected authorization context for `accountID`, or nil
    /// when that account does not own the current session. Identifiers
    /// only — the expectation carries no credential.
    func expectation(accountID: String) -> AuthorizationExpectation? {
        lock.lock()
        defer { lock.unlock() }
        guard self.accountID == accountID, accessToken != nil else { return nil }
        return AuthorizationExpectation(accountID: accountID, sessionEpoch: sessionEpoch)
    }

    /// The atomic bind: validates that the expected account still owns the
    /// session under the SAME epoch and snapshots its current credential,
    /// all under one lock acquisition. Returns nil when the expectation is
    /// stale (account replaced, logged out, deleted, or A → B → A since
    /// capture) — callers must fail before transmission, never fall back to
    /// the mutable current token.
    func bindCredential(expectation: AuthorizationExpectation) -> AuthorizationCredentialSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard accountID == expectation.accountID,
              sessionEpoch == expectation.sessionEpoch,
              let accessToken else {
            return nil
        }
        return AuthorizationCredentialSnapshot(
            accountID: expectation.accountID,
            sessionEpoch: sessionEpoch,
            accessToken: accessToken
        )
    }
}
