import Foundation
import GamePediaProduct22API

// MARK: - ProductConfigStore
//
// Holds the last known-good product configuration and decides what the app is
// allowed to offer.
//
// Rules it implements:
//
//   - refreshed at launch, on foreground, and on manual pull-to-refresh
//   - the last good config is cached for a short TTL and is ACCOUNT
//     INDEPENDENT: kill switches are a property of the deployment, not of the
//     signed-in user, so switching accounts does not invalidate it and it
//     never leaks per-user data (it holds none)
//   - past the TTL with no successful refresh, it falls back to fail-closed
//   - a degraded flag state disables every new feature while leaving every
//     pre-existing app feature untouched
//   - a 503 from any Product 2.2 call feeds back in here so the app converges
//     on a stable state instead of showing a retry button that cannot succeed

actor ProductConfigStore {

    /// Short enough that a kill switch takes effect quickly, long enough that
    /// normal navigation does not re-fetch on every screen.
    static let cacheTTL: TimeInterval = 5 * 60

    private let service: any Product22APIServicing
    private let now: @Sendable () -> Date

    private var cached: Product22ProductConfig?
    private var cachedAt: Date?
    private var inFlight: Task<Product22ProductConfig, Never>?
    private var observers: [UUID: @Sendable (Product22ProductConfig) -> Void] = [:]

    init(
        service: any Product22APIServicing,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.now = now
    }

    // MARK: Reading

    /// The configuration to make decisions from right now. Never nil: an
    /// unknown state is fail-closed, not "assume enabled".
    var current: Product22ProductConfig {
        guard let cached, let cachedAt, now().timeIntervalSince(cachedAt) < Self.cacheTTL else {
            return .failClosed
        }
        return cached
    }

    /// True when the cached config is still inside its TTL. Used to decide
    /// whether a screen is showing a decision made from stale information.
    var isFresh: Bool {
        guard let cachedAt else { return false }
        return now().timeIntervalSince(cachedAt) < Self.cacheTTL
    }

    func isEnabled(_ feature: Product22Feature) -> Bool {
        current.isEnabled(feature)
    }

    // MARK: Refreshing

    /// Refreshes if the cache has expired; returns the cached value otherwise.
    @discardableResult
    func refreshIfNeeded() async -> Product22ProductConfig {
        if isFresh, let cached { return cached }
        return await refresh()
    }

    /// Unconditional refresh. Concurrent callers share one request rather than
    /// stampeding the endpoint on launch + foreground + pull-to-refresh.
    @discardableResult
    func refresh() async -> Product22ProductConfig {
        if let inFlight { return await inFlight.value }

        // The task yields nil on failure rather than a synthetic config, so a
        // flaky network can never be mistaken for a kill switch.
        let task = Task<Product22ProductConfig?, Never> { [service] in
            guard let dto = try? await service.fetchProductConfig() else { return nil }
            return ProductConfigMapper.map(dto)
        }
        inFlight = Task { await task.value ?? self.current }
        let fetched = await task.value
        inFlight = nil

        if let fetched {
            cached = fetched
            cachedAt = now()
        } else if cached == nil {
            // Never heard from the server at all: fail closed, and start the
            // TTL so the next read retries rather than pinning this forever.
            cached = .failClosed
            cachedAt = now()
        }
        // A failed refresh with a still-fresh cache leaves both untouched, so
        // the TTL continues to expire on its original schedule.

        notify(current)
        return current
    }

    /// Called when any Product 2.2 call reports a kill switch. The config is
    /// refetched so the whole app converges on the new state at once instead of
    /// each screen discovering it separately.
    func handleFeatureUnavailable(_ reason: FeatureUnavailableReason) async {
        // A degraded flag state is authoritative on its own: the server has
        // told us it cannot read the table, so stop offering new features
        // immediately rather than waiting for the refresh to land.
        if reason == .stateUnavailable {
            cached = Product22ProductConfig(
                dtoVersion: cached?.dtoVersion ?? 0,
                productVersion: cached?.productVersion ?? "unknown",
                generatedAt: now(),
                isDegraded: true,
                enabledFeatures: [],
                allowedEventCodes: cached?.allowedEventCodes
            )
            cachedAt = now()
            notify(current)
        }
        invalidate()
        await refresh()
    }

    /// Drops the cache so the next read refreshes. Does not clear on account
    /// change: the configuration is not account scoped.
    func invalidate() {
        cachedAt = nil
    }

    // MARK: Observation

    func addObserver(_ observer: @escaping @Sendable (Product22ProductConfig) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        observer(current)
        return id
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func notify(_ config: Product22ProductConfig) {
        for observer in observers.values { observer(config) }
    }
}

// MARK: - ProductConfigMapper

enum ProductConfigMapper {

    static func map(_ dto: Components.Schemas.ProductConfig) -> Product22ProductConfig {
        let degraded = dto.featureFlagStateDegraded
            || dto.featureFlagSource == .database_unavailable

        var enabled: Set<Product22Feature> = []
        let flags = dto.features
        if flags.openCatalog { enabled.insert(.openCatalog) }
        if flags.aiQuickAdd { enabled.insert(.aiQuickAdd) }
        if flags.playlog { enabled.insert(.playlog) }
        if flags.playCompass { enabled.insert(.playCompass) }
        if flags.gameDNA { enabled.insert(.gameDNA) }
        if flags.monthlyReplay { enabled.insert(.monthlyReplay) }
        if flags.todayFeed { enabled.insert(.todayFeed) }
        if flags.magazine { enabled.insert(.magazine) }

        return Product22ProductConfig(
            dtoVersion: dto.dtoVersion,
            productVersion: dto.productVersion,
            generatedAt: dto.generatedAt,
            isDegraded: degraded,
            enabledFeatures: enabled,
            allowedEventCodes: eventCodes(from: dto.allowlists)
        )
    }

    /// `allowlists` is declared as a bare `{"type": "object"}`, so the contract
    /// names none of its keys and the generated type is untyped JSON.
    ///
    /// This reads it *defensively*: if a `productEventCodes` array of strings
    /// happens to be there, it is used to narrow what the app sends; if it is
    /// absent or shaped differently, the result is nil and the app falls back
    /// to the contract's own `eventCode` enum. The value can therefore only
    /// ever restrict, never widen — nothing depends on this key existing, and
    /// an event's validity is guaranteed by the generated enum regardless.
    private static func eventCodes(
        from allowlists: Product22JSONObject
    ) -> Set<String>? {
        guard let codes = Product22JSON.stringArray(allowlists, key: "productEventCodes"),
              !codes.isEmpty else {
            return nil
        }
        return Set(codes)
    }
}
