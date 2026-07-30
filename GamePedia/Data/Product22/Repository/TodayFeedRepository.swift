import Foundation

// MARK: - CachedTodayFeed

struct CachedTodayFeed: Equatable, Sendable {
    let feed: TodayFeed
    let cachedAt: Date
    /// True when it is being shown past its freshness window, so the UI can
    /// say "this is from a moment ago" instead of implying it is live.
    let isStale: Bool
}

// MARK: - TodayFeedRepositing

protocol TodayFeedRepositing: Sendable {
    /// Cached feed for the signed-in account, or nil. Never returns another
    /// account's feed, and never returns anything to a signed-out caller.
    func cachedFeed() async -> CachedTodayFeed?
    func loadFeed(locale: String?, timezone: String, forceRefresh: Bool) async throws -> TodayFeed
    func clearCache(for accountID: String?) async
    func clearAll() async
}

// MARK: - TodayFeedRepository
//
// Owns the Today cache and the rules that keep one account's feed away from
// another's.
//
// Account isolation is structural, not a cleanup step:
//
//   - every cache entry is stored under the account that fetched it
//   - a read resolves the account first and only then looks up the entry, so
//     a signed-out or switched session cannot reach the previous account's
//     data even if nothing cleared it
//   - a response that arrives after the account changed is discarded rather
//     than written, which is the case a "clear on logout" hook misses
//
// Stale-response suppression works the same way. Each load takes a monotonic
// token; when it finishes, it writes only if it is still the newest load for
// the same account. A slow first request can therefore never overwrite the
// result of a faster later one.

actor TodayFeedRepository: TodayFeedRepositing {

    /// How long a cached feed is presented as current. Past this it is still
    /// shown — an old Today beats an empty screen — but marked stale.
    static let freshnessWindow: TimeInterval = 10 * 60

    private let service: any Product22APIServicing
    private let authority: SessionCredentialAuthority
    private let now: @Sendable () -> Date

    private struct Entry {
        let feed: TodayFeed
        let cachedAt: Date
    }

    private var cache: [String: Entry] = [:]
    private var latestToken: [String: UInt64] = [:]
    private var tokenCounter: UInt64 = 0

    init(
        service: any Product22APIServicing,
        authority: SessionCredentialAuthority = APIClient.shared.credentialAuthority,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.authority = authority
        self.now = now
    }

    // MARK: Reading

    func cachedFeed() async -> CachedTodayFeed? {
        guard let accountID = authority.currentAccountID,
              let entry = cache[accountID] else {
            return nil
        }
        let age = now().timeIntervalSince(entry.cachedAt)
        return CachedTodayFeed(
            feed: entry.feed,
            cachedAt: entry.cachedAt,
            isStale: age >= Self.freshnessWindow
        )
    }

    func loadFeed(
        locale: String?,
        timezone: String,
        forceRefresh: Bool
    ) async throws -> TodayFeed {
        guard let accountID = authority.currentAccountID else {
            // Today is an authenticated surface. A signed-out caller gets a
            // definite answer, not somebody else's cached feed.
            throw Product22Error.unauthorized
        }

        if !forceRefresh,
           let entry = cache[accountID],
           now().timeIntervalSince(entry.cachedAt) < Self.freshnessWindow {
            return entry.feed
        }

        tokenCounter &+= 1
        let token = tokenCounter
        latestToken[accountID] = token

        let dto = try await service.fetchTodayFeed(
            locale: locale,
            timezone: timezone,
            // The contract caps Today at 8 sections, which is exactly the
            // number the feed composes.
            limit: 8
        )
        let feed = TodayFeedMapper.map(dto)

        // Three ways this response can be obsolete by the time it lands.
        guard authority.currentAccountID == accountID else {
            // The account changed mid-flight: this belongs to nobody now.
            throw Product22Error.accountChanged
        }
        guard latestToken[accountID] == token else {
            // A newer load already answered. Returning the feed is fine —
            // the caller asked for it — but it must not become the cache.
            return feed
        }

        cache[accountID] = Entry(feed: feed, cachedAt: now())
        return feed
    }

    // MARK: Invalidation

    /// Called on logout and on account deletion.
    func clearCache(for accountID: String?) async {
        guard let accountID else { return }
        cache[accountID] = nil
        latestToken[accountID] = nil
    }

    /// Called when the session is torn down entirely.
    func clearAll() async {
        cache.removeAll()
        latestToken.removeAll()
    }

    // MARK: Diagnostics

    var cachedAccountIDs: Set<String> { Set(cache.keys) }
}
