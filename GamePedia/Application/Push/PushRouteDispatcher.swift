import Combine
import Foundation

enum PushRouteEvent: Hashable {
    case route(PushNotificationPayload)
}

final class PushRouteDispatcher {
    static let shared = PushRouteDispatcher()

    let publisher = PassthroughSubject<PushRouteEvent, Never>()
    private var pendingPayload: PushNotificationPayload?

    private init() {}

    func send(_ event: PushRouteEvent) {
        if case .route(let payload) = event {
            pendingPayload = payload
        }
        publisher.send(event)
    }

    func drainPendingRoute() -> PushNotificationPayload? {
        let payload = pendingPayload
        pendingPayload = nil
        return payload
    }
}
