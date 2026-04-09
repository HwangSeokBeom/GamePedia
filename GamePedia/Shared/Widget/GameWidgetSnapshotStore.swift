import Foundation

protocol GameWidgetSnapshotStoring: AnyObject {
    func saveRecentViewed(_ snapshot: RecentViewedWidgetSnapshot)
    func loadRecentViewed() -> RecentViewedWidgetSnapshot?
    func saveTrendingGames(_ snapshot: TrendingGamesWidgetSnapshot)
    func loadTrendingGames() -> TrendingGamesWidgetSnapshot?
    func saveMyActivity(_ snapshot: MyActivityWidgetSnapshot)
    func loadMyActivity() -> MyActivityWidgetSnapshot?
    func saveReviewPrompt(_ snapshot: ReviewPromptWidgetSnapshot)
    func loadReviewPrompt() -> ReviewPromptWidgetSnapshot?
    func saveRecentViewedRecords(_ records: [RecentViewedGameRecord])
    func loadRecentViewedRecords() -> [RecentViewedGameRecord]
}

final class GameWidgetSnapshotStore: GameWidgetSnapshotStoring {
    static let shared = GameWidgetSnapshotStore()

    private enum Keys {
        static let recentViewed = "gamepedia.widget.recent_viewed.v1"
        static let trendingGames = "gamepedia.widget.trending_games.v1"
        static let myActivity = "gamepedia.widget.my_activity.v1"
        static let reviewPrompt = "gamepedia.widget.review_prompt.v1"
        static let recentViewedRecords = "gamepedia.widget.recent_viewed.records.v1"
    }

    private let userDefaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        appGroupIdentifier: String? = Bundle.main.object(forInfoDictionaryKey: "WidgetAppGroupIdentifier") as? String,
        userDefaults: UserDefaults? = nil
    ) {
        let normalizedAppGroupIdentifier = appGroupIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let userDefaults {
            self.userDefaults = userDefaults
        } else if let normalizedAppGroupIdentifier,
                  normalizedAppGroupIdentifier.isEmpty == false {
            self.userDefaults = UserDefaults(suiteName: normalizedAppGroupIdentifier)
        } else {
            self.userDefaults = nil
        }
    }

    func saveRecentViewed(_ snapshot: RecentViewedWidgetSnapshot) {
        save(snapshot, forKey: Keys.recentViewed)
    }

    func loadRecentViewed() -> RecentViewedWidgetSnapshot? {
        load(RecentViewedWidgetSnapshot.self, forKey: Keys.recentViewed)
    }

    func saveTrendingGames(_ snapshot: TrendingGamesWidgetSnapshot) {
        save(snapshot, forKey: Keys.trendingGames)
    }

    func loadTrendingGames() -> TrendingGamesWidgetSnapshot? {
        load(TrendingGamesWidgetSnapshot.self, forKey: Keys.trendingGames)
    }

    func saveMyActivity(_ snapshot: MyActivityWidgetSnapshot) {
        save(snapshot, forKey: Keys.myActivity)
    }

    func loadMyActivity() -> MyActivityWidgetSnapshot? {
        load(MyActivityWidgetSnapshot.self, forKey: Keys.myActivity)
    }

    func saveReviewPrompt(_ snapshot: ReviewPromptWidgetSnapshot) {
        save(snapshot, forKey: Keys.reviewPrompt)
    }

    func loadReviewPrompt() -> ReviewPromptWidgetSnapshot? {
        load(ReviewPromptWidgetSnapshot.self, forKey: Keys.reviewPrompt)
    }

    func saveRecentViewedRecords(_ records: [RecentViewedGameRecord]) {
        save(records, forKey: Keys.recentViewedRecords)
    }

    func loadRecentViewedRecords() -> [RecentViewedGameRecord] {
        load([RecentViewedGameRecord].self, forKey: Keys.recentViewedRecords) ?? []
    }

    func recordRecentViewed(_ record: RecentViewedGameRecord, limit: Int = 12) {
        guard record.gameID > 0 else { return }
        let existing = loadRecentViewedRecords().filter { $0.gameID != record.gameID }
        saveRecentViewedRecords(Array(([record] + existing).prefix(limit)))
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let userDefaults,
              let data = try? encoder.encode(value) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let userDefaults,
              let data = userDefaults.data(forKey: key) else {
            return nil
        }

        guard let value = try? decoder.decode(type, from: data) else {
            userDefaults.removeObject(forKey: key)
            return nil
        }

        return value
    }
}
