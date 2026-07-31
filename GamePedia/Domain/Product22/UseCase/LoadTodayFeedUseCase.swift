import Foundation

// MARK: - TodayFeedLoading
//
// Home's single entry point into Product 2.2. Everything Home needs to know
// about kill switches, sign-in state and caching is decided behind this.

protocol TodayFeedLoading: Sendable {
    /// The feed to show, or nil when Today should not appear at all.
    ///
    /// Nil is a normal outcome, not a failure: the kill switch is off, the
    /// flag state is degraded, or nobody is signed in. Home renders its
    /// pre-existing discovery experience in that case, unchanged.
    func load(forceRefresh: Bool) async -> TodayFeedLoadResult
}

// MARK: - TodayFeedLoadResult

enum TodayFeedLoadResult: Equatable {
    /// Show this feed. `isStale` marks a cached feed past its freshness window.
    case feed(TodayFeed, isStale: Bool)
    /// Do not show Today. Home keeps its existing experience.
    case unavailable(TodayUnavailableReason)
}

enum TodayUnavailableReason: Equatable {
    /// Nobody is signed in. Every Product 2.2 route requires a session, so
    /// there is nothing to ask for.
    case signedOut
    /// The `todayFeed` kill switch is off, or the flag state is degraded and
    /// the app is failing closed.
    case featureOff
    /// The request failed and there was nothing cached to fall back on.
    case loadFailed
}

// MARK: - LoadTodayFeedUseCase

/// Composes the product configuration gate with the account-isolated feed
/// repository.
///
/// The order matters: configuration is consulted *before* the feed request, so
/// a disabled feature costs no network call and cannot briefly flash content
/// on its way to being hidden.
struct LoadTodayFeedUseCase: TodayFeedLoading {

    private let configStore: ProductConfigStore
    private let repository: any TodayFeedRepositing
    private let authority: SessionCredentialAuthority
    private let localeProvider: @Sendable () -> String?
    private let timeZoneProvider: @Sendable () -> TimeZone

    init(
        configStore: ProductConfigStore,
        repository: any TodayFeedRepositing,
        authority: SessionCredentialAuthority = APIClient.shared.credentialAuthority,
        localeProvider: @escaping @Sendable () -> String? = { Locale.current.language.languageCode?.identifier },
        timeZoneProvider: @escaping @Sendable () -> TimeZone = { TimeZone.current }
    ) {
        self.configStore = configStore
        self.repository = repository
        self.authority = authority
        self.localeProvider = localeProvider
        self.timeZoneProvider = timeZoneProvider
    }

    func load(forceRefresh: Bool) async -> TodayFeedLoadResult {
        guard authority.currentAccountID != nil else { return .unavailable(.signedOut) }

        // Fail closed: an unknown or degraded configuration offers nothing new.
        let config = await configStore.refreshIfNeeded()
        guard config.isEnabled(.todayFeed) else { return .unavailable(.featureOff) }

        do {
            let feed = try await repository.loadFeed(
                locale: localeProvider(),
                timezone: timeZoneProvider().identifier,
                forceRefresh: forceRefresh
            )
            let cached = await repository.cachedFeed()
            return .feed(feed, isStale: cached?.isStale ?? false)
        } catch let error as Product22Error {
            // A kill switch discovered mid-flight converges the whole app on
            // the new state rather than leaving this one screen guessing.
            if case .featureUnavailable(let reason) = error {
                await configStore.handleFeatureUnavailable(reason)
                return .unavailable(.featureOff)
            }
            if case .unauthorized = error { return .unavailable(.signedOut) }
            // Cancellation is not a failure and must not be rendered as one.
            if error.isCancellation, let cached = await repository.cachedFeed() {
                return .feed(cached.feed, isStale: cached.isStale)
            }
            // An old feed beats an empty screen, as long as it is marked old.
            if let cached = await repository.cachedFeed() {
                return .feed(cached.feed, isStale: true)
            }
            return .unavailable(.loadFailed)
        } catch {
            if let cached = await repository.cachedFeed() {
                return .feed(cached.feed, isStale: true)
            }
            return .unavailable(.loadFailed)
        }
    }
}

// MARK: - Live composition

extension LoadTodayFeedUseCase {
    /// The wiring the app uses. Kept here so a screen never has to know how
    /// the Product 2.2 stack is assembled.
    static func live() -> LoadTodayFeedUseCase {
        let service = DefaultProduct22APIService()
        return LoadTodayFeedUseCase(
            configStore: Product22Runtime.shared.configStore(service: service),
            repository: TodayFeedRepository(service: service)
        )
    }
}

// MARK: - Product22Runtime
//
// One process-wide product configuration store. The kill-switch state is a
// property of the deployment, not of a screen, and two stores would refresh
// twice and could briefly disagree with each other.

final class Product22Runtime: @unchecked Sendable {

    static let shared = Product22Runtime()

    private let lock = NSLock()
    private var store: ProductConfigStore?

    private init() {}

    func configStore(service: any Product22APIServicing) -> ProductConfigStore {
        lock.lock()
        defer { lock.unlock() }
        if let store { return store }
        let created = ProductConfigStore(service: service)
        store = created
        return created
    }
}
