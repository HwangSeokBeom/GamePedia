import Combine
import Foundation

enum SocialActivityAppEvent: Hashable {
    case showBanner(SocialActivityBannerPayload)
    case route(SocialActivityRoute)
}

final class SocialActivityEventDispatcher {
    static let shared = SocialActivityEventDispatcher()

    let publisher = PassthroughSubject<SocialActivityAppEvent, Never>()

    private init() {}

    func send(_ event: SocialActivityAppEvent) {
        publisher.send(event)
    }
}

final class SocialActivityDeduplicator {
    static let shared = SocialActivityDeduplicator()

    private let lock = NSLock()
    private var seenEvents: [String: Date] = [:]
    private let defaultTimeToLive: TimeInterval = 60 * 10

    private init() {}

    func shouldProcess(_ identity: String, timeToLive: TimeInterval? = nil) -> Bool {
        let ttl = timeToLive ?? defaultTimeToLive
        let now = Date()

        lock.lock()
        defer { lock.unlock() }

        seenEvents = seenEvents.filter { now.timeIntervalSince($0.value) < ttl }
        guard seenEvents[identity] == nil else { return false }
        seenEvents[identity] = now
        return true
    }
}
