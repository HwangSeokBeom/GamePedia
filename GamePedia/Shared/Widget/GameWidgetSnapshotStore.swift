import Foundation

protocol GameWidgetSnapshotStoring: AnyObject {
    func saveTrendingGames(_ snapshot: TrendingGamesWidgetSnapshot)
    func loadTrendingGames() -> TrendingGamesWidgetSnapshot?
    func saveReviewPrompt(_ snapshot: ReviewPromptWidgetSnapshot)
    func loadReviewPrompt() -> ReviewPromptWidgetSnapshot?
}

final class GameWidgetSnapshotStore: GameWidgetSnapshotStoring {
    static let shared = GameWidgetSnapshotStore()

    private enum Keys {
        static let trendingGames = "gamepedia.widget.trending_games.v1"
        static let reviewPrompt = "gamepedia.widget.review_prompt.v1"
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

    func saveTrendingGames(_ snapshot: TrendingGamesWidgetSnapshot) {
        save(snapshot, forKey: Keys.trendingGames)
    }

    func loadTrendingGames() -> TrendingGamesWidgetSnapshot? {
        load(TrendingGamesWidgetSnapshot.self, forKey: Keys.trendingGames)
    }

    func saveReviewPrompt(_ snapshot: ReviewPromptWidgetSnapshot) {
        save(snapshot, forKey: Keys.reviewPrompt)
    }

    func loadReviewPrompt() -> ReviewPromptWidgetSnapshot? {
        load(ReviewPromptWidgetSnapshot.self, forKey: Keys.reviewPrompt)
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
