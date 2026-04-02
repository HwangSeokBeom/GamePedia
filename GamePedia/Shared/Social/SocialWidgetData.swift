import Foundation

struct FriendActivitySummaryWidgetData: Codable, Hashable {
    struct Item: Codable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        let actorAvatarURL: URL?
        let gameCoverURL: URL?
        let timestampText: String
    }

    let generatedAt: Date
    let title: String
    let summary: String
    let items: [Item]
}

struct RecommendedGameWidgetData: Codable, Hashable {
    let generatedAt: Date
    let gameID: Int?
    let title: String
    let subtitle: String
    let coverImageURL: URL?
    let ratingText: String?
}

final class SocialWidgetSnapshotStore {
    static let shared = SocialWidgetSnapshotStore()

    private let friendActivityKey = "gamepedia.social.widget.friend_activity"
    private let recommendedGameKey = "gamepedia.social.widget.recommended_game"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = AppConfig.widgetAppGroupIdentifier.flatMap(UserDefaults.init(suiteName:))) {
        self.userDefaults = userDefaults
    }

    func saveFriendActivitySummary(_ data: FriendActivitySummaryWidgetData) {
        guard let userDefaults, let encoded = try? encoder.encode(data) else { return }
        userDefaults.set(encoded, forKey: friendActivityKey)
    }

    func saveRecommendedGame(_ data: RecommendedGameWidgetData) {
        guard let userDefaults, let encoded = try? encoder.encode(data) else { return }
        userDefaults.set(encoded, forKey: recommendedGameKey)
    }

    func loadFriendActivitySummary() -> FriendActivitySummaryWidgetData? {
        guard let userDefaults,
              let data = userDefaults.data(forKey: friendActivityKey),
              let decoded = try? decoder.decode(FriendActivitySummaryWidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }

    func loadRecommendedGame() -> RecommendedGameWidgetData? {
        guard let userDefaults,
              let data = userDefaults.data(forKey: recommendedGameKey),
              let decoded = try? decoder.decode(RecommendedGameWidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
