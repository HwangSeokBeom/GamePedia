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

    static func defaults(for environment: APIEnvironment) -> FeatureFlags {
        switch environment {
        case .dev, .staging, .production:
            return FeatureFlags(
                enableSocialLogin: true,
                enableReportFeature: true,
                enableNewReviewUI: false,
                useExperimentalSearch: false,
                enableRealtimeActivity: false
            )
        }
    }
}
