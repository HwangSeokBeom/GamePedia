import Foundation

// MARK: - LiveServiceRuntime
//
// App-side composition for the 2.4 live-service foundation. Mirrors
// RealtimeRuntime / LibrarySyncRuntime: a singleton composition root
// started from AppDelegate that owns
//
// - the feature availability provider (client-side kill-switch boundary),
// - the operation breadcrumb recorder (incident-safe timeline),
// - the account-scoped Activity Center stores (read state + last-known
//   snapshot),
// - the current account identity, bridged from the existing auth-session
//   notifications.
//
// Account rules: logout clears the active account (stores stay on disk,
// unreadable without the account scope); account deletion purges the
// deleted account's files; an account switch can never read or write the
// previous account's state because every store call is keyed by the
// account ID captured at call time.
//
// Session generations: every change of the account SCOPE (login, logout,
// switch, deletion — not a same-account token refresh) bumps a generation.
// Long-lived async work captures `currentSession` when it starts and
// revalidates it before every side effect (render, persistence, badge
// posts, mark-read, widget writes); a mismatch makes the work inert.

/// Account-scope snapshot async work binds itself to. Equal only when both
/// the account and the generation match, so A→logout→A is two different
/// sessions and stale work from the first can never commit into the second.
struct LiveServiceSession: Equatable, Sendable {
    let accountID: String?
    let generation: UInt64
}

final class LiveServiceRuntime {
    static let shared = LiveServiceRuntime()

    let availability: LocalFeatureAvailabilityProvider
    let breadcrumbs: OperationBreadcrumbRecorder
    let readStateStore: ActivityReadStateStore
    let snapshotStore: FileActivityCenterSnapshotStore

    private let notificationCenter: NotificationCenter
    private let socialWidgetStore: SocialWidgetSnapshotStore
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []
    private var started = false
    private var accountID: String?
    private var sessionGeneration: UInt64 = 0

    init(
        featureFlags: FeatureFlags = AppConfig.featureFlags,
        notificationCenter: NotificationCenter = .default,
        breadcrumbs: OperationBreadcrumbRecorder = .shared,
        readStateStore: ActivityReadStateStore? = nil,
        snapshotStore: FileActivityCenterSnapshotStore? = nil,
        socialWidgetStore: SocialWidgetSnapshotStore = .shared
    ) {
        self.notificationCenter = notificationCenter
        self.breadcrumbs = breadcrumbs
        self.socialWidgetStore = socialWidgetStore
        availability = LocalFeatureAvailabilityProvider(
            enableUnifiedActivityCenter: featureFlags.enableUnifiedActivityCenter,
            enableRealtimeActivity: featureFlags.enableRealtimeActivity,
            enableOfflineLibrarySync: featureFlags.enableOfflineLibrarySync,
            notificationCenter: notificationCenter
        )
        self.readStateStore = readStateStore ?? ActivityReadStateStore()
        self.snapshotStore = snapshotStore ?? FileActivityCenterSnapshotStore()
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    /// The account scope for Activity Center state; nil in guest mode.
    var currentAccountID: String? {
        lock.lock()
        defer { lock.unlock() }
        return accountID
    }

    /// The session async work must bind itself to. Compare against a
    /// captured copy after every await; a mismatch means the work belongs
    /// to a superseded session and must not commit anything.
    var currentSession: LiveServiceSession {
        lock.lock()
        defer { lock.unlock() }
        return LiveServiceSession(accountID: accountID, generation: sessionGeneration)
    }

    /// Idempotent. Bridges auth-session and availability notifications.
    func start() {
        lock.lock()
        let alreadyStarted = started
        started = true
        lock.unlock()
        guard !alreadyStarted else { return }

        observers.append(
            notificationCenter.addObserver(
                forName: .authSessionDidChange,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                let isAuthenticated = notification
                    .userInfo?[AuthSessionChangeUserInfoKey.isAuthenticated] as? Bool ?? false
                let userID = notification
                    .userInfo?[AuthSessionChangeUserInfoKey.userId] as? String
                self?.handleSessionChange(isAuthenticated: isAuthenticated, userID: userID)
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: .authAccountDidDelete,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let self,
                      let userID = notification
                        .userInfo?[AuthSessionChangeUserInfoKey.userId] as? String else { return }
                self.handleAccountDeletionMarker(userID: userID)
                Task { await self.purgeAccountState(userID: userID) }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: .liveServiceAvailabilityDidChange,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let self else { return }
                let featureRawValue = notification
                    .userInfo?[LiveServiceAvailabilityUserInfoKey.feature] as? String ?? "unknown"
                let state: String
                if let feature = LiveServiceFeature(rawValue: featureRawValue) {
                    state = self.availability.availability(for: feature).code
                } else {
                    state = "unknown"
                }
                self.breadcrumbs.record(
                    .availability,
                    code: "availability_changed",
                    metadata: ["feature": featureRawValue, "state": state]
                )
            }
        )
    }

    // MARK: Session bridging (internal for deterministic tests)

    func handleSessionChange(isAuthenticated: Bool, userID: String?) {
        lock.lock()
        let previousAccountID = accountID
        accountID = isAuthenticated ? userID : nil
        // A same-account re-authentication (token refresh) keeps the
        // session: in-flight work for that account stays valid.
        let scopeChanged = previousAccountID != accountID
        if scopeChanged {
            sessionGeneration &+= 1
        }
        lock.unlock()
        if scopeChanged {
            socialWidgetStore.handleSessionTransition()
        }
        breadcrumbs.record(
            .session,
            code: isAuthenticated ? "session_authenticated" : "session_guest"
        )
    }

    func handleAccountDeletionMarker(userID: String) {
        lock.lock()
        let scopeChanged = accountID == userID
        if scopeChanged {
            accountID = nil
            sessionGeneration &+= 1
        }
        lock.unlock()
        if scopeChanged {
            socialWidgetStore.handleSessionTransition()
        }
        breadcrumbs.record(.session, code: "account_state_purged")
    }

    func purgeAccountState(userID: String) async {
        await readStateStore.purge(accountID: userID)
        await snapshotStore.purge(accountID: userID)
    }
}
