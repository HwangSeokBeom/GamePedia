import Foundation

// MARK: - AppMetric
// Canonical identifiers for locally measured performance intervals.
// Names are static and privacy-safe: they never embed user input, tokens,
// URLs, query values, or payload contents.

enum AppMetric: String, CaseIterable {
    case coldLaunch = "cold_launch"
    case firstHomeRender = "first_home_render"
    case searchRoundTrip = "search_round_trip"
    case gameDetailLoad = "game_detail_load"
    case authRefresh = "auth_refresh"
    case friendActivityRefresh = "friend_activity_refresh"
    case realtimeConnect = "realtime_connect"

    var signpostName: StaticString {
        switch self {
        case .coldLaunch: return "ColdLaunch"
        case .firstHomeRender: return "FirstHomeRender"
        case .searchRoundTrip: return "SearchRoundTrip"
        case .gameDetailLoad: return "GameDetailLoad"
        case .authRefresh: return "AuthRefresh"
        case .friendActivityRefresh: return "FriendActivityRefresh"
        case .realtimeConnect: return "RealtimeConnect"
        }
    }
}

enum MetricOutcome: String {
    case success
    case failure
    case cancelled
}

// A completed local measurement. Duration only — no request/response data.
struct MetricSample: Equatable {
    let metric: AppMetric
    let durationMilliseconds: Double
    let outcome: MetricOutcome
    let endedAt: Date
}
