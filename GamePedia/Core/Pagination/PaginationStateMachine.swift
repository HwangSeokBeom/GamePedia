import Foundation

// MARK: - PaginationStateMachine
//
// Pure, deterministic pagination state machine shared by paged lists.
// It owns the decisions that were previously hand-rolled per screen
// (`isLoadInFlight` + cursor juggling in the friend activity feed; no
// guard at all in notifications):
//
// - single-flight: at most one load may be active
// - duplicate-page rejection: a page token can be loaded at most once
//   per dataset generation, and a server echoing the same token back
//   terminates pagination instead of looping
// - stale-completion rejection: completions carry the generation they
//   started in; completions from before a reset are ignored
// - explicit reset/refresh semantics that start a new dataset generation
//
// The machine holds no items and performs no I/O. Callers ask to begin a
// load, perform the fetch themselves, then report completion or failure
// with the returned descriptor.

struct PaginationLoad<PageToken: Hashable & Sendable>: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case initial
        case refresh
        case nextPage
    }

    let kind: Kind
    /// nil requests the first page.
    let token: PageToken?
    /// Dataset generation this load belongs to; used to drop stale completions.
    let generation: Int

    var isReset: Bool {
        kind != .nextPage
    }
}

struct PaginationStateMachine<PageToken: Hashable & Sendable>: Sendable {

    enum Phase: Equatable, Sendable {
        case idle
        case loadingInitial
        case refreshing
        case loadingMore
        case failed
    }

    private(set) var phase: Phase = .idle
    private(set) var nextPageToken: PageToken?
    private(set) var hasLoadedInitialPage = false

    private var generation = 0
    private var inFlightLoad: PaginationLoad<PageToken>?
    private var loadedTokens: Set<PageToken> = []

    // MARK: UI-facing flags

    var isLoadingInitial: Bool { phase == .loadingInitial }
    var isRefreshing: Bool { phase == .refreshing }
    var isLoadingMore: Bool { phase == .loadingMore }
    var isLoadInFlight: Bool { inFlightLoad != nil }
    var hasMorePages: Bool { nextPageToken != nil }

    // MARK: Begin

    /// First load of the dataset. Rejected while any load is in flight.
    mutating func beginInitial() -> PaginationLoad<PageToken>? {
        guard inFlightLoad == nil else { return nil }
        let load = PaginationLoad<PageToken>(kind: .initial, token: nil, generation: generation)
        inFlightLoad = load
        phase = .loadingInitial
        return load
    }

    /// User-initiated reload from the first page. Rejected while any load
    /// is in flight (existing feed behavior: refresh does not preempt).
    mutating func beginRefresh() -> PaginationLoad<PageToken>? {
        guard inFlightLoad == nil else { return nil }
        let load = PaginationLoad<PageToken>(kind: .refresh, token: nil, generation: generation)
        inFlightLoad = load
        phase = hasLoadedInitialPage ? .refreshing : .loadingInitial
        return load
    }

    /// Loads the next page. Rejected when a load is in flight, when the
    /// initial page has not loaded, when there is no next token, or when
    /// the next token was already loaded in this generation (duplicate
    /// page): in that last case pagination terminates.
    mutating func beginNextPage() -> PaginationLoad<PageToken>? {
        guard inFlightLoad == nil,
              hasLoadedInitialPage,
              let token = nextPageToken else { return nil }
        guard loadedTokens.contains(token) == false else {
            nextPageToken = nil
            return nil
        }
        let load = PaginationLoad<PageToken>(kind: .nextPage, token: token, generation: generation)
        inFlightLoad = load
        phase = .loadingMore
        return load
    }

    // MARK: Complete

    /// Reports a successful load. Returns false — and mutates nothing —
    /// for stale completions (generation mismatch or no matching flight).
    /// A `nextToken` equal to the loaded token or to an already-loaded
    /// token terminates pagination instead of allowing a duplicate page.
    @discardableResult
    mutating func completeLoad(_ load: PaginationLoad<PageToken>, nextToken: PageToken?) -> Bool {
        guard isCurrent(load) else { return false }
        inFlightLoad = nil
        phase = .idle
        hasLoadedInitialPage = true

        if load.isReset {
            loadedTokens = []
        }
        if let token = load.token {
            loadedTokens.insert(token)
        }

        if let nextToken, nextToken != load.token, loadedTokens.contains(nextToken) == false {
            nextPageToken = nextToken
        } else {
            nextPageToken = nil
        }
        return true
    }

    /// Reports a failed load. Returns false for stale completions.
    /// Failure keeps the previous `nextPageToken` for reset loads at nil
    /// and preserves the token for next-page loads so retry is possible.
    @discardableResult
    mutating func failLoad(_ load: PaginationLoad<PageToken>) -> Bool {
        guard isCurrent(load) else { return false }
        inFlightLoad = nil
        phase = .failed
        return true
    }

    /// Abandons everything and returns to the pristine state, invalidating
    /// all in-flight completions via a new generation.
    mutating func reset() {
        generation += 1
        inFlightLoad = nil
        phase = .idle
        nextPageToken = nil
        hasLoadedInitialPage = false
        loadedTokens = []
    }

    private func isCurrent(_ load: PaginationLoad<PageToken>) -> Bool {
        load.generation == generation && inFlightLoad == load
    }
}
