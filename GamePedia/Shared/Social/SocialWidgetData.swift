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

// MARK: - SocialWidgetSnapshotStore
//
// App-group persistence for social widget payloads, scoped to a session
// generation.
//
// Session isolation contract:
// - every payload is stamped with the session generation that wrote it;
// - the generation is a random UUID rotated by the app on every account
//   transition (login, logout, switch, deletion) — it is deliberately
//   non-identifying and carries no relationship to any account ID;
// - rotation also deletes the stored payloads, so no session's social data
//   survives into the next session;
// - readers (widgets) reject any payload whose stamp does not match the
//   current generation — a delayed write from a previous session that lands
//   after rotation is discarded on read;
// - no raw account identifier, token, or credential is ever persisted here.

final class SocialWidgetSnapshotStore {
    static let shared = SocialWidgetSnapshotStore()

    /// Payload wrapper binding data to the session generation that wrote it.
    private struct SessionScoped<Payload: Codable>: Codable {
        let sessionGeneration: String
        let payload: Payload
    }

    private let friendActivityKey = "gamepedia.social.widget.friend_activity"
    private let recommendedGameKey = "gamepedia.social.widget.recommended_game"
    private let sessionGenerationKey = "gamepedia.social.widget.session_generation"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let userDefaults: UserDefaults?
    private let makeGeneration: () -> String

    init(
        userDefaults: UserDefaults? = AppConfig.widgetAppGroupIdentifier.flatMap(UserDefaults.init(suiteName:)),
        makeGeneration: @escaping () -> String = { UUID().uuidString }
    ) {
        self.userDefaults = userDefaults
        self.makeGeneration = makeGeneration
    }

    /// Rotates the session generation and clears every social payload.
    /// Called by the app on every account transition (login, logout,
    /// account switch, account deletion): the old generation's payloads are
    /// removed, and any straggler write stamped with the old generation is
    /// rejected by readers.
    func handleSessionTransition() {
        guard let userDefaults else { return }
        userDefaults.removeObject(forKey: friendActivityKey)
        userDefaults.removeObject(forKey: recommendedGameKey)
        userDefaults.set(makeGeneration(), forKey: sessionGenerationKey)
    }

    /// The active session generation, creating one on first use so writes
    /// before any explicit transition are still scoped.
    var currentSessionGeneration: String? {
        guard let userDefaults else { return nil }
        if let existing = userDefaults.string(forKey: sessionGenerationKey) {
            return existing
        }
        let created = makeGeneration()
        userDefaults.set(created, forKey: sessionGenerationKey)
        return created
    }

    func saveFriendActivitySummary(_ data: FriendActivitySummaryWidgetData) {
        save(data, forKey: friendActivityKey)
    }

    func saveRecommendedGame(_ data: RecommendedGameWidgetData) {
        save(data, forKey: recommendedGameKey)
    }

    func loadFriendActivitySummary() -> FriendActivitySummaryWidgetData? {
        load(FriendActivitySummaryWidgetData.self, forKey: friendActivityKey)
    }

    func loadRecommendedGame() -> RecommendedGameWidgetData? {
        load(RecommendedGameWidgetData.self, forKey: recommendedGameKey)
    }

    // MARK: Private

    private func save<Payload: Codable>(_ payload: Payload, forKey key: String) {
        guard let userDefaults,
              let generation = currentSessionGeneration,
              let encoded = try? encoder.encode(
                SessionScoped(sessionGeneration: generation, payload: payload)
              ) else { return }
        userDefaults.set(encoded, forKey: key)
    }

    private func load<Payload: Codable>(_ type: Payload.Type, forKey key: String) -> Payload? {
        guard let userDefaults,
              let data = userDefaults.data(forKey: key) else {
            return nil
        }
        guard let scoped = try? decoder.decode(SessionScoped<Payload>.self, from: data),
              scoped.sessionGeneration == currentSessionGeneration else {
            // Stale generation, a pre-generation legacy payload, or an
            // undecodable blob: never surface it, and delete it so it
            // cannot resurface.
            userDefaults.removeObject(forKey: key)
            return nil
        }
        return scoped.payload
    }
}
