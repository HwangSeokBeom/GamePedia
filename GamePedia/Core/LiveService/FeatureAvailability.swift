import Foundation

// MARK: - Feature availability (client-side kill-switch boundary)
//
// A single, testable answer to "is this live-service capability usable
// right now?". Every consumer asks the provider instead of reading
// FeatureFlags directly, so critical infrastructure can be disabled
// through one boundary and tests can exercise both sides of the switch.
//
// There is NO remote implementation: the backend has no remote-config or
// kill-switch contract (docs/backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md).
// The local provider resolves build-time FeatureFlags plus in-process
// overrides (DEBUG menu and tests). Server-controlled rollout is
// explicitly not claimed.

enum LiveServiceFeature: String, CaseIterable, Sendable {
    /// The unified Activity Center surface (2.4). Disabling reverts the
    /// notification bell to the legacy Notifications screen.
    case unifiedActivityCenter
    /// Realtime activity channel (2.1). Never available in production:
    /// no committed backend contract exists.
    case realtimeActivity
    /// Offline-first library sync queue (2.2).
    case offlineLibrarySync
    /// In-app social push banners. Disabling falls back to the system
    /// notification presentation; pushes are never silently dropped.
    case socialPushBanners
}

enum FeatureUnavailabilityReason: String, Sendable {
    case disabledByConfiguration
    case noBackendContract
    case localOverride
}

enum FeatureAvailabilityState: Equatable, Sendable {
    case available
    case unavailable(FeatureUnavailabilityReason)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// Stable machine-readable code for logs and diagnostics.
    var code: String {
        switch self {
        case .available:
            return "available"
        case .unavailable(let reason):
            return "unavailable_\(reason.rawValue)"
        }
    }
}

extension Notification.Name {
    /// Posted when a feature's availability changes at runtime (local
    /// override). userInfo carries the feature raw value under
    /// `LiveServiceAvailabilityUserInfoKey.feature`.
    static let liveServiceAvailabilityDidChange = Notification.Name("liveServiceAvailabilityDidChange")
}

enum LiveServiceAvailabilityUserInfoKey {
    static let feature = "feature"
}

protocol FeatureAvailabilityProviding: AnyObject, Sendable {
    func availability(for feature: LiveServiceFeature) -> FeatureAvailabilityState
}

/// Local/deterministic provider: build-time flags + in-process overrides.
/// Thread-safe; override changes are announced through NotificationCenter
/// so composition roots can react (and record breadcrumbs) without the
/// provider knowing about them.
final class LocalFeatureAvailabilityProvider: FeatureAvailabilityProviding, @unchecked Sendable {

    private let lock = NSLock()
    private let defaults: [LiveServiceFeature: FeatureAvailabilityState]
    private var overrides: [LiveServiceFeature: FeatureAvailabilityState] = [:]
    private let notificationCenter: NotificationCenter

    init(
        enableUnifiedActivityCenter: Bool,
        enableRealtimeActivity: Bool,
        enableOfflineLibrarySync: Bool,
        notificationCenter: NotificationCenter = .default
    ) {
        var defaults: [LiveServiceFeature: FeatureAvailabilityState] = [:]
        defaults[.unifiedActivityCenter] = enableUnifiedActivityCenter
            ? .available
            : .unavailable(.disabledByConfiguration)
        // Mirrors RealtimeRuntime: even with the flag on, the remote
        // transport is intentionally absent until a committed contract
        // exists, so the feature can never resolve to available.
        defaults[.realtimeActivity] = enableRealtimeActivity
            ? .unavailable(.noBackendContract)
            : .unavailable(.disabledByConfiguration)
        defaults[.offlineLibrarySync] = enableOfflineLibrarySync
            ? .available
            : .unavailable(.disabledByConfiguration)
        defaults[.socialPushBanners] = .available
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    func availability(for feature: LiveServiceFeature) -> FeatureAvailabilityState {
        lock.lock()
        defer { lock.unlock() }
        return overrides[feature] ?? defaults[feature] ?? .unavailable(.disabledByConfiguration)
    }

    /// Applies (or clears, when nil) a runtime override. This is the local
    /// kill-switch: DEBUG tooling and tests use it; production has no
    /// remote path to it by design.
    func setOverride(_ state: FeatureAvailabilityState?, for feature: LiveServiceFeature) {
        lock.lock()
        let previous = overrides[feature] ?? defaults[feature]
        if let state {
            overrides[feature] = state
        } else {
            overrides.removeValue(forKey: feature)
        }
        let current = overrides[feature] ?? defaults[feature]
        lock.unlock()

        guard previous != current else { return }
        notificationCenter.post(
            name: .liveServiceAvailabilityDidChange,
            object: nil,
            userInfo: [LiveServiceAvailabilityUserInfoKey.feature: feature.rawValue]
        )
    }
}
