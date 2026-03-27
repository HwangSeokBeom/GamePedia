import Foundation

struct FeatureFlags {
    let enableSocialLogin: Bool
    let enableReportFeature: Bool
    let enableNewReviewUI: Bool
    let useExperimentalSearch: Bool

    static func defaults(for environment: APIEnvironment) -> FeatureFlags {
        switch environment {
        case .dev, .staging, .production:
            return FeatureFlags(
                enableSocialLogin: true,
                enableReportFeature: true,
                enableNewReviewUI: false,
                useExperimentalSearch: false
            )
        }
    }
}
