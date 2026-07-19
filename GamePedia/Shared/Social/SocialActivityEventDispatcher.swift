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

// Thin façade over the unified live-activity dedup registry (2.4). Push
// banner and push route suppression now share the same registry that the
// Activity Center pipeline uses, so one logical activity is processed
// once regardless of the channel that delivered it. A suppressed
// duplicate leaves an incident breadcrumb (identity keys are built from
// stable identifiers only — safe to record).
final class SocialActivityDeduplicator {
    static let shared = SocialActivityDeduplicator()

    private let deduplicator = LiveActivityDeduplicator()

    private init() {}

    func shouldProcess(_ identity: String, timeToLive: TimeInterval? = nil) -> Bool {
        let shouldProcess = deduplicator.shouldProcess(
            LiveActivityIdentity(rawValue: identity),
            timeToLive: timeToLive
        )
        if shouldProcess == false {
            OperationBreadcrumbRecorder.shared.record(.push, code: "duplicate_suppressed")
        }
        return shouldProcess
    }
}
