import Foundation
import UIKit

// MARK: - RealtimeRuntime
//
// App-side composition for the realtime foundation. Bridges the existing
// auth-session notification and UIKit lifecycle notifications into the hub.
//
// Production behavior: `FeatureFlags.enableRealtimeActivity` is false in
// every environment AND no remote transport exists (the backend has no
// committed realtime contract), so the hub is permanently
// `.unavailable(...)` and feature code falls back to pure REST behavior.
// Deterministic mock transports are used only by unit tests and the DEBUG
// diagnostics demo, never by this production wiring.

final class RealtimeRuntime {
    static let shared = RealtimeRuntime()

    let hub: RealtimeHub
    let isRealtimeEnabled: Bool

    private let notificationCenter: NotificationCenter
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []
    private var started = false

    init(
        featureFlags: FeatureFlags = AppConfig.featureFlags,
        client: RealtimeClient? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.notificationCenter = notificationCenter
        isRealtimeEnabled = featureFlags.enableRealtimeActivity

        let resolvedClient: RealtimeClient
        if let client {
            resolvedClient = client
        } else if featureFlags.enableRealtimeActivity {
            // Flag on but still no committed backend contract: the remote
            // implementation is intentionally absent, never guessed.
            resolvedClient = UnavailableRealtimeClient(reason: .noBackendContract)
        } else {
            resolvedClient = UnavailableRealtimeClient(reason: .featureDisabled)
        }
        hub = RealtimeHub(client: resolvedClient)
    }

    deinit {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
    }

    /// Idempotent. Registers session/lifecycle bridging; the hub itself does
    /// nothing until a subscriber exists and a session is authenticated.
    func start() {
        lock.lock()
        let alreadyStarted = started
        started = true
        lock.unlock()
        guard !alreadyStarted else { return }

        let hub = self.hub

        observers.append(
            notificationCenter.addObserver(
                forName: .authSessionDidChange,
                object: nil,
                queue: nil
            ) { notification in
                let isAuthenticated = notification
                    .userInfo?[AuthSessionChangeUserInfoKey.isAuthenticated] as? Bool ?? false
                Task { await hub.sessionDidChange(isAuthenticated: isAuthenticated) }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: nil
            ) { _ in
                Task { await hub.appDidEnterBackground() }
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: nil
            ) { _ in
                Task { await hub.appWillEnterForeground() }
            }
        )
    }
}
