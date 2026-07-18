import Foundation

struct ActivityCenterState {
    var isLoading: Bool = false
    var items: [ActivityCenterItem] = []
    var sourceHealth: ActivitySourceHealth = .allFresh
    /// True when items are the persisted last-known snapshot (all live
    /// sources failed).
    var isShowingLastKnown: Bool = false
    var lastKnownGeneratedAt: Date? = nil
    var errorMessage: String? = nil

    var isEmpty: Bool {
        !isLoading && items.isEmpty && errorMessage == nil
    }

    /// Degraded-service notice; nil when everything is fresh. Degraded
    /// mode always keeps the screen usable and the retry path visible.
    var degradedNoticeText: String? {
        if isShowingLastKnown {
            return L10n.tr("Localizable", "activityCenter.degraded.lastKnown")
        }
        if sourceHealth.isFullyFresh == false {
            return L10n.tr("Localizable", "activityCenter.degraded.partial")
        }
        return nil
    }
}
