import Foundation
import WidgetKit

struct TrendingGamesWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TrendingGamesWidgetSnapshot
}

struct ReviewPromptWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: ReviewPromptWidgetSnapshot
}

struct TrendingGamesWidgetProvider: TimelineProvider {
    private let snapshotStore = GameWidgetSnapshotStore.shared

    func placeholder(in context: Context) -> TrendingGamesWidgetEntry {
        TrendingGamesWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrendingGamesWidgetEntry) -> Void) {
        let snapshot = snapshotStore.loadTrendingGames() ?? .placeholder
        completion(TrendingGamesWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendingGamesWidgetEntry>) -> Void) {
        let snapshot = snapshotStore.loadTrendingGames() ?? .placeholder
        let entry = TrendingGamesWidgetEntry(date: .now, snapshot: snapshot)
        let timeline = Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(60 * 60))
        )
        completion(timeline)
    }
}

struct ReviewPromptWidgetProvider: TimelineProvider {
    private let snapshotStore = GameWidgetSnapshotStore.shared

    func placeholder(in context: Context) -> ReviewPromptWidgetEntry {
        ReviewPromptWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReviewPromptWidgetEntry) -> Void) {
        let snapshot = snapshotStore.loadReviewPrompt() ?? .placeholder
        completion(ReviewPromptWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReviewPromptWidgetEntry>) -> Void) {
        let snapshot = snapshotStore.loadReviewPrompt() ?? .placeholder
        let entry = ReviewPromptWidgetEntry(date: .now, snapshot: snapshot)
        let timeline = Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(60 * 60 * 6))
        )
        completion(timeline)
    }
}
