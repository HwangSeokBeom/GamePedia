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

final class LiveServiceRuntime {
    static let shared = LiveServiceRuntime()

    let availability: LocalFeatureAvailabilityProvider
    let breadcrumbs: OperationBreadcrumbRecorder
    let readStateStore: ActivityReadStateStore
    let snapshotStore: FileActivityCenterSnapshotStore

    private let notificationCenter: NotificationCenter
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []
    private var started = false
    private var accountID: String?

    init(
        featureFlags: FeatureFlags = AppConfig.featureFlags,
        notificationCenter: NotificationCenter = .default,
        breadcrumbs: OperationBreadcrumbRecorder = .shared,
        readStateStore: ActivityReadStateStore? = nil,
        snapshotStore: FileActivityCenterSnapshotStore? = nil
    ) {
        self.notificationCenter = notificationCenter
        self.breadcrumbs = breadcrumbs
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
        accountID = isAuthenticated ? userID : nil
        lock.unlock()
        breadcrumbs.record(
            .session,
            code: isAuthenticated ? "session_authenticated" : "session_guest"
        )
    }

    func handleAccountDeletionMarker(userID: String) {
        lock.lock()
        if accountID == userID {
            accountID = nil
        }
        lock.unlock()
        breadcrumbs.record(.session, code: "account_state_purged")
    }

    func purgeAccountState(userID: String) async {
        await readStateStore.purge(accountID: userID)
        await snapshotStore.purge(accountID: userID)
    }
}
