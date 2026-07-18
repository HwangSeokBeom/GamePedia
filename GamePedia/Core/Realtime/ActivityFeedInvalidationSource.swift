import Foundation

// MARK: - ActivityFeedInvalidationSignaling
//
// Boundary between the realtime foundation and the Friend Activity feature.
// The feed never renders realtime payloads: a signal is only a hint that the
// authoritative REST feed should be reconciled. When realtime is disabled or
// unavailable (the production state today), the source is simply absent and
// the feed behaves exactly as before.

protocol ActivityFeedInvalidationSignaling {
    /// Reconciliation hints. The stream ends when the subscription ends.
    func signals() -> AsyncStream<Void>
}

final class RealtimeActivityFeedInvalidationSource: ActivityFeedInvalidationSignaling {
    private let hub: RealtimeHub

    init(hub: RealtimeHub = RealtimeRuntime.shared.hub) {
        self.hub = hub
    }

    func signals() -> AsyncStream<Void> {
        let hub = self.hub
        return AsyncStream { continuation in
            let task = Task {
                let subscription = await hub.subscribe()
                for await signal in subscription.signals {
                    switch signal {
                    case .reconciliationRequired:
                        continuation.yield(())
                    case .event(let event):
                        // Accepted friend-activity events are also treated as
                        // invalidation hints only — never rendered directly.
                        if case .friendActivity = event.type {
                            continuation.yield(())
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                // Cancelling the task ends the hub subscription stream, which
                // triggers the hub's per-subscriber cleanup.
                task.cancel()
            }
        }
    }
}
