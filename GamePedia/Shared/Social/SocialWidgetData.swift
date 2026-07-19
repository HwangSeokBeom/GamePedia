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

// MARK: - SocialWidgetSaveResult

/// Outcome of a generation-guarded widget save. The caller must never treat
/// anything but `.saved` as success.
enum SocialWidgetSaveResult: Equatable {
    /// The expected generation matched and the payload was persisted,
    /// stamped with that same generation.
    case saved
    /// The producer's captured generation no longer matches the stored one
    /// — an account transition happened after capture. Nothing was written.
    case rejectedStaleGeneration
    /// Storage was unavailable or the write failed. Nothing usable was
    /// written.
    case storageFailure
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
// - a producer captures its expected generation token while it still owns
//   the authenticated session and passes that exact token into the save;
//   the store compares it against the stored generation, stamps the payload
//   with the SAME token, and persists — all inside one lock, so a save can
//   never observe generation G, lose the CPU to a rotation, and then be
//   stamped with G'. The store never substitutes a newer generation for an
//   older producer's;
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
    private let persistData: (UserDefaults, Data, String) -> Bool
    // The single synchronization boundary for compare + stamp + persist:
    // rotation, generation reads, saves, and reads all serialize here.
    private let lock = NSLock()

    init(
        userDefaults: UserDefaults? = AppConfig.widgetAppGroupIdentifier.flatMap(UserDefaults.init(suiteName:)),
        makeGeneration: @escaping () -> String = { UUID().uuidString },
        persistData: @escaping (UserDefaults, Data, String) -> Bool = { defaults, data, key in
            defaults.set(data, forKey: key)
            return true
        }
    ) {
        self.userDefaults = userDefaults
        self.makeGeneration = makeGeneration
        self.persistData = persistData
    }

    /// Rotates the session generation and clears every social payload.
    /// Called by the app on every account transition (login, logout,
    /// account switch, account deletion): the old generation's payloads are
    /// removed, any straggler save carrying the old generation token is
    /// rejected atomically, and any old blob that still lands is rejected
    /// by readers.
    func handleSessionTransition() {
        guard let userDefaults else { return }
        lock.lock()
        defer { lock.unlock() }
        userDefaults.removeObject(forKey: friendActivityKey)
        userDefaults.removeObject(forKey: recommendedGameKey)
        userDefaults.set(makeGeneration(), forKey: sessionGenerationKey)
    }

    /// The token a producer must capture while it still owns the
    /// authenticated session and pass unchanged into the save. Created on
    /// first use so writes before any explicit transition are still scoped.
    func captureGenerationToken() -> String? {
        guard let userDefaults else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return activeGeneration(in: userDefaults)
    }

    /// The active session generation (readers and tests).
    var currentSessionGeneration: String? {
        captureGenerationToken()
    }

    func saveFriendActivitySummary(
        _ data: FriendActivitySummaryWidgetData,
        expectedGeneration: String?
    ) -> SocialWidgetSaveResult {
        save(data, forKey: friendActivityKey, expectedGeneration: expectedGeneration)
    }

    func saveRecommendedGame(
        _ data: RecommendedGameWidgetData,
        expectedGeneration: String?
    ) -> SocialWidgetSaveResult {
        save(data, forKey: recommendedGameKey, expectedGeneration: expectedGeneration)
    }

    func loadFriendActivitySummary() -> FriendActivitySummaryWidgetData? {
        load(FriendActivitySummaryWidgetData.self, forKey: friendActivityKey)
    }

    func loadRecommendedGame() -> RecommendedGameWidgetData? {
        load(RecommendedGameWidgetData.self, forKey: recommendedGameKey)
    }

    // MARK: Private

    /// Atomic compare-and-stamp-and-persist. The comparison against the
    /// stored generation, the stamping of the payload with the producer's
    /// OWN expected token, and the write share one lock; the current
    /// generation is never re-read between them.
    private func save<Payload: Codable>(
        _ payload: Payload,
        forKey key: String,
        expectedGeneration: String?
    ) -> SocialWidgetSaveResult {
        guard let userDefaults else { return .storageFailure }
        guard let expectedGeneration, expectedGeneration.isEmpty == false else {
            // A producer without a captured token has no proof it ever
            // owned the current session; refuse rather than adopt the
            // current generation on its behalf.
            return .rejectedStaleGeneration
        }
        lock.lock()
        defer { lock.unlock() }
        guard expectedGeneration == activeGeneration(in: userDefaults) else {
            return .rejectedStaleGeneration
        }
        guard let encoded = try? encoder.encode(
            SessionScoped(sessionGeneration: expectedGeneration, payload: payload)
        ) else {
            return .storageFailure
        }
        guard persistData(userDefaults, encoded, key) else {
            return .storageFailure
        }
        return .saved
    }

    private func load<Payload: Codable>(_ type: Payload.Type, forKey key: String) -> Payload? {
        guard let userDefaults else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        guard let scoped = try? decoder.decode(SessionScoped<Payload>.self, from: data),
              scoped.sessionGeneration == activeGeneration(in: userDefaults) else {
            // Stale generation, a pre-generation legacy payload, or an
            // undecodable blob: never surface it, and delete it so it
            // cannot resurface.
            userDefaults.removeObject(forKey: key)
            return nil
        }
        return scoped.payload
    }

    /// Reads (or lazily creates) the stored generation. Callers must hold
    /// `lock`.
    private func activeGeneration(in userDefaults: UserDefaults) -> String {
        if let existing = userDefaults.string(forKey: sessionGenerationKey) {
            return existing
        }
        let created = makeGeneration()
        userDefaults.set(created, forKey: sessionGenerationKey)
        return created
    }
}
