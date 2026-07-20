import Foundation
import Network
import UIKit

// MARK: - Connectivity

protocol ConnectivityObserving {
    /// Starts observing; the handler receives `true` when the network path
    /// is satisfied. May be called back on any queue.
    func startObserving(onChange: @escaping @Sendable (Bool) -> Void)
    func stopObserving()
}

final class NWPathConnectivityObserver: ConnectivityObserving {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.gamepedia.sync.connectivity")

    func startObserving(onChange: @escaping @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            onChange(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    func stopObserving() {
        monitor.cancel()
    }
}

// MARK: - LibrarySyncRuntime
//
// App-side composition for the offline-first library sync foundation.
// Mirrors `RealtimeRuntime`: a singleton composition root started from
// `AppDelegate` that bridges the existing auth-session notification, the
// account-deletion notification, UIKit lifecycle, and network-path changes
// into the actor-isolated engine.
//
// `FeatureFlags.enableOfflineLibrarySync` is the kill-switch: when false the
// runtime exposes no mutation router, and every call site falls back to the
// pre-2.2 direct REST mutation path unchanged.

final class LibrarySyncRuntime {
    static let shared = LibrarySyncRuntime()

    let isEnabled: Bool
    let engine: LibrarySyncEngine?

    private let notificationCenter: NotificationCenter
    private let connectivityObserver: any ConnectivityObserving
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []
    private var started = false

    init(
        featureFlags: FeatureFlags = AppConfig.featureFlags,
        store: (any SyncOperationStoring)? = nil,
        transport: (any LibrarySyncTransporting)? = nil,
        connectivityObserver: (any ConnectivityObserving)? = nil,
        notificationCenter: NotificationCenter = .default,
        engineConfiguration: LibrarySyncEngine.Configuration = LibrarySyncEngine.Configuration(),
        jitterSource: any JitterSourcing = SystemJitterSource(),
        sleeper: any RealtimeSleeping = TaskRealtimeSleeper()
    ) {
        self.notificationCenter = notificationCenter
        self.connectivityObserver = connectivityObserver ?? NWPathConnectivityObserver()
        isEnabled = featureFlags.enableOfflineLibrarySync

        if isEnabled {
            engine = LibrarySyncEngine(
                store: store ?? FileSyncOperationStore(),
                transport: transport ?? RESTLibrarySyncTransport(),
                configuration: engineConfiguration,
                jitterSource: jitterSource,
                sleeper: sleeper,
                notificationCenter: notificationCenter
            )
        } else {
            engine = nil
        }
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        connectivityObserver.stopObserving()
    }

    /// The mutation router feature code injects. Nil when the feature is
    /// disabled, which reverts every call site to the direct REST path.
    var mutationRouter: (any LibraryMutationSyncing)? { engine }

    /// Idempotent. The engine does nothing until an authenticated session
    /// event arrives with a user ID.
    func start() {
        lock.lock()
        let alreadyStarted = started
        started = true
        lock.unlock()
        guard !alreadyStarted, let engine else { return }

        observers.append(
            notificationCenter.addObserver(
                forName: .authSessionDidChange,
                object: nil,
                queue: nil
            ) { notification in
                let isAuthenticated = notification
                    .userInfo?[AuthSessionChangeUserInfoKey.isAuthenticated] as? Bool ?? false
                let userID = notification
                    .userInfo?[AuthSessionChangeUserInfoKey.userId] as? String
                // Gesture-time ownership adopts the new scope synchronously,
                // inside the notification delivery: a gesture performed after
                // this event can only capture the new account, and captures
                // from the old scope are already stale — even though the
                // engine's own adoption below is asynchronous.
                engine.ownershipContext.adoptSession(
                    isAuthenticated: isAuthenticated,
                    userID: userID
                )
                Task {
                    await engine.sessionDidChange(isAuthenticated: isAuthenticated, userID: userID)
                }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: .authAccountDidDelete,
                object: nil,
                queue: nil
            ) { notification in
                guard let userID = notification
                    .userInfo?[AuthSessionChangeUserInfoKey.userId] as? String else { return }
                // Same synchronous ownership invalidation as the session
                // bridge: no gesture may capture the deleted account's scope
                // after this notification.
                engine.ownershipContext.invalidateAccount(userID)
                Task { await engine.accountDidDelete(userID: userID) }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { _ in
                Task { await engine.appWillEnterForeground() }
            }
        )

        connectivityObserver.startObserving { isSatisfied in
            Task { await engine.connectivityDidChange(isSatisfied: isSatisfied) }
        }
    }
}
