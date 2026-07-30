import Foundation
import GamePediaProduct22API
import OpenAPIRuntime

// MARK: - ProductEventCode
//
// Mirrors the contract's `eventCode` enum. Declaring it here rather than
// passing raw strings around means an event the contract does not define
// cannot be constructed at all, and `wire` maps onto the generated enum so a
// contract change breaks the build instead of failing at runtime.

enum ProductEventCode: String, CaseIterable, Sendable {
    case quickAddPreview = "quick_add_preview"
    case quickAddConfirm = "quick_add_confirm"
    case playCompassSubmit = "play_compass_submit"
    case playCompassSelect = "play_compass_select"
    case playSessionCreate = "play_session_create"
    case gameDNAView = "game_dna_view"
    case replayView = "replay_view"
    case replayShare = "replay_share"
    case articleImpression = "article_impression"
    case articleAction = "article_action"

    var wire: ProductEventPayload.eventCodePayload {
        switch self {
        case .quickAddPreview: return .quick_add_preview
        case .quickAddConfirm: return .quick_add_confirm
        case .playCompassSubmit: return .play_compass_submit
        case .playCompassSelect: return .play_compass_select
        case .playSessionCreate: return .play_session_create
        case .gameDNAView: return .game_dna_view
        case .replayView: return .replay_view
        case .replayShare: return .replay_share
        case .articleImpression: return .article_impression
        case .articleAction: return .article_action
        }
    }

    /// Property keys this event may carry. Anything not listed is dropped
    /// before the batch is built.
    ///
    /// Every key here is a shape, a count, a code or a public content
    /// identifier. None of them can hold user-authored text: no Playlog note,
    /// no mood, no Quick Add natural-language input, no article body, no
    /// source URL, no search query, no credential. `ProductEventProperties`
    /// enforces that structurally — its value type cannot express free text
    /// beyond a short enumerated code.
    var allowedPropertyKeys: Set<String> {
        switch self {
        case .quickAddPreview:
            return ["input_type", "region_code", "resolution_stage", "ai_used",
                    "ai_fallback_used", "candidate_count", "requires_title_confirmation"]
        case .quickAddConfirm:
            return ["linked_existing", "requested_public_review", "outcome"]
        case .playCompassSubmit:
            return ["available_minutes", "energy", "solo_or_party",
                    "continue_or_start", "platform_count", "friend_count"]
        case .playCompassSelect:
            return ["action", "rank", "reason_code_count", "confidence"]
        case .playSessionCreate:
            // Deliberately no `mood` and no note content — only whether a note
            // exists at all, which the product needs and which reveals nothing
            // about what the user wrote.
            return ["outcome", "visibility", "has_duration", "has_progress", "has_note", "entry_point"]
        case .gameDNAView:
            return ["confidence", "signal_count"]
        case .replayView:
            return ["month_key", "is_empty"]
        case .replayShare:
            return ["month_key"]
        case .articleImpression:
            return ["slug", "status", "placement"]
        case .articleAction:
            return ["slug", "action"]
        }
    }
}

// MARK: - ProductEventProperties
//
// A property bag that cannot hold free text.
//
// The value type is the enforcement: `.code` is capped at 64 characters and
// restricted to an identifier-ish character set, which no note, prose input,
// article body or URL survives. There is no `.text` case, so "just this once"
// is not available to a future caller.

struct ProductEventProperties: Equatable, Sendable {

    enum Value: Equatable, Sendable {
        case code(String)
        case count(Int)
        case flag(Bool)
    }

    private(set) var storage: [String: Value] = [:]

    init() {}

    static let maxCodeLength = 64
    private static let allowedCodeCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.:"
    )

    /// Adds an enumerated code. Rejected — silently, because analytics must
    /// never break a user action — if it is too long or contains anything
    /// other than identifier characters. A sentence, a URL or a note fails all
    /// three tests.
    mutating func set(_ key: String, code: String) {
        guard !code.isEmpty,
              code.count <= Self.maxCodeLength,
              code.unicodeScalars.allSatisfy({ Self.allowedCodeCharacters.contains($0) })
        else { return }
        storage[key] = .code(code)
    }

    mutating func set(_ key: String, count: Int) { storage[key] = .count(count) }
    mutating func set(_ key: String, flag: Bool) { storage[key] = .flag(flag) }

    /// Drops every key the event code does not allow. Called once, centrally,
    /// so a new call site cannot bypass it.
    func filtered(for code: ProductEventCode) -> ProductEventProperties {
        var result = ProductEventProperties()
        let allowed = code.allowedPropertyKeys
        for (key, value) in storage where allowed.contains(key) {
            result.storage[key] = value
        }
        return result
    }

    var isEmpty: Bool { storage.isEmpty }

    func asJSONObject() throws -> OpenAPIObjectContainer {
        var raw: [String: (any Sendable)?] = [:]
        for (key, value) in storage {
            switch value {
            case .code(let string): raw[key] = string
            case .count(let int): raw[key] = int
            case .flag(let bool): raw[key] = bool
            }
        }
        return try OpenAPIObjectContainer(unvalidatedValue: raw)
    }
}

// MARK: - ProductEvent

struct ProductEvent: Equatable, Sendable {
    /// Stable across every retry of the same occurrence — that is what makes
    /// the batch idempotent server-side. A new user action gets a new id; a
    /// resend never does.
    let eventID: String
    let code: ProductEventCode
    let occurredAt: Date
    let properties: ProductEventProperties
    /// Account the event belongs to. A batch is only ever sent while this
    /// account still owns the session.
    let accountID: String
}

// MARK: - ProductEventRecording

protocol ProductEventRecording: Sendable {
    func record(_ code: ProductEventCode, properties: ProductEventProperties) async
    func flush() async
}

// MARK: - ProductEventRecorder
//
// Buffers allowlisted events and ships them in batches.
//
// Held in memory only. Analytics is not worth writing user activity to disk:
// the queue would then need the same encryption, file protection and
// account-deletion cleanup as Playlog notes, for data whose loss on a force
// quit costs nothing.

actor ProductEventRecorder: ProductEventRecording {

    /// The contract caps a batch at 50 events.
    static let maxBatchSize = 50
    /// Beyond this the oldest events are dropped: an unbounded buffer on a
    /// device with no connectivity is a memory leak.
    static let maxQueueDepth = 200
    private static let maxAttempts = 4

    private let service: any Product22APIServicing
    private let configStore: ProductConfigStore
    private let authority: SessionCredentialAuthority
    private let now: @Sendable () -> Date
    private let newEventID: @Sendable () -> String

    private var queue: [ProductEvent] = []
    private var seenEventIDs: Set<String> = []
    private var isFlushing = false
    private var consecutiveFailures = 0
    private var nextAttemptAllowedAt: Date?

    init(
        service: any Product22APIServicing,
        configStore: ProductConfigStore,
        authority: SessionCredentialAuthority = APIClient.shared.credentialAuthority,
        now: @escaping @Sendable () -> Date = { Date() },
        newEventID: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.service = service
        self.configStore = configStore
        self.authority = authority
        self.now = now
        self.newEventID = newEventID
    }

    // MARK: Recording

    func record(_ code: ProductEventCode, properties: ProductEventProperties) async {
        guard let accountID = authority.currentAccountID else { return }

        // Two gates. The contract enum is the hard one — an undeclared code
        // cannot be constructed. The config allowlist can only narrow further,
        // and when the server did not name one, the contract stands alone.
        let config = await configStore.current
        if let allowed = config.allowedEventCodes, !allowed.contains(code.rawValue) {
            return
        }

        let event = ProductEvent(
            eventID: newEventID(),
            code: code,
            occurredAt: now(),
            properties: properties.filtered(for: code),
            accountID: accountID
        )
        enqueue(event)
    }

    private func enqueue(_ event: ProductEvent) {
        guard !seenEventIDs.contains(event.eventID) else { return }
        seenEventIDs.insert(event.eventID)
        queue.append(event)
        if queue.count > Self.maxQueueDepth {
            let overflow = queue.count - Self.maxQueueDepth
            let dropped = Array(queue.prefix(overflow))
            queue.removeFirst(overflow)
            for event in dropped { seenEventIDs.remove(event.eventID) }
        }
    }

    // MARK: Flushing

    func flush() async {
        guard !isFlushing else { return }
        if let nextAttemptAllowedAt, now() < nextAttemptAllowedAt { return }
        guard authority.currentAccountID != nil else {
            // Signed out: nothing may be attributed to whoever signs in next.
            discardEventsNotBelongingToCurrentAccount()
            return
        }

        discardEventsNotBelongingToCurrentAccount()
        let batch = Array(queue.prefix(Self.maxBatchSize))
        guard !batch.isEmpty else { return }

        isFlushing = true
        defer { isFlushing = false }

        do {
            try await service.submitProductEvents(batch.map(payload(for:)))
            // Only the events actually accepted leave the queue.
            queue.removeFirst(min(batch.count, queue.count))
            for event in batch { seenEventIDs.remove(event.eventID) }
            consecutiveFailures = 0
            nextAttemptAllowedAt = nil
        } catch {
            // Analytics never surfaces. The events keep their ids so a retry
            // is idempotent rather than double counting.
            consecutiveFailures += 1
            if consecutiveFailures >= Self.maxAttempts {
                queue.removeFirst(min(batch.count, queue.count))
                for event in batch { seenEventIDs.remove(event.eventID) }
                consecutiveFailures = 0
                nextAttemptAllowedAt = nil
            } else {
                let backoff = pow(2.0, Double(consecutiveFailures)) * 5
                nextAttemptAllowedAt = now().addingTimeInterval(backoff)
            }
            // Account for the session having ended during a bad batch.
            if case Product22Error.unauthorized = error { queue.removeAll() }
        }
    }

    private func discardEventsNotBelongingToCurrentAccount() {
        let accountID = authority.currentAccountID
        let kept = queue.filter { $0.accountID == accountID }
        guard kept.count != queue.count else { return }
        let removed = Set(queue.map(\.eventID)).subtracting(kept.map(\.eventID))
        seenEventIDs.subtract(removed)
        queue = kept
    }

    /// Drops everything queued for accounts other than the one now signed in.
    func handleAccountChange() {
        discardEventsNotBelongingToCurrentAccount()
        consecutiveFailures = 0
        nextAttemptAllowedAt = nil
    }

    private func payload(for event: ProductEvent) -> ProductEventPayload {
        ProductEventPayload(
            eventId: event.eventID,
            eventCode: event.code.wire,
            occurredAt: event.occurredAt,
            properties: try? event.properties.asJSONObject()
        )
    }

    // MARK: Test/diagnostic access

    var pendingEventIDs: [String] { queue.map(\.eventID) }
    var pendingCount: Int { queue.count }
}
