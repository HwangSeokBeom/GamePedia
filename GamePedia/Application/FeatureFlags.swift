import Foundation

struct FeatureFlags {
    let enableSocialLogin: Bool
    let enableReportFeature: Bool
    let enableNewReviewUI: Bool
    let useExperimentalSearch: Bool
    // Disabled everywhere: the backend has no committed realtime contract.
    // The realtime foundation stays REST-only until one exists
    // (docs/backend/REALTIME_CONTRACT_REQUEST.md).
    let enableRealtimeActivity: Bool
    // Kill-switch for the offline-first library sync queue. The queue only
    // replays committed, replay-convergent REST mutations; disabling it
    // reverts every library mutation to the pre-2.2 direct call path
    // (docs/backend/LIBRARY_SYNC_CONTRACT_REQUEST.md).
    let enableOfflineLibrarySync: Bool
    // Kill-switch for the unified Activity Center (2.4). The surface only
    // composes the two existing committed REST contracts (notification
    // inbox + friend activity feed); disabling it reverts the notification
    // bell to the legacy Notifications screen unchanged.
    let enableUnifiedActivityCenter: Bool

    static func defaults(for environment: APIEnvironment) -> FeatureFlags {
        switch environment {
        case .dev, .staging, .production:
            return FeatureFlags(
                enableSocialLogin: true,
                enableReportFeature: true,
                enableNewReviewUI: false,
                useExperimentalSearch: false,
                enableRealtimeActivity: false,
                enableOfflineLibrarySync: true,
                enableUnifiedActivityCenter: true
            )
        }
    }
}
