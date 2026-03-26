import Foundation

// MARK: - LocalUserActivityRepository
//
// Simple local persistence for recommendation seeds.
// Stores viewed/liked/exposure history in UserDefaults so home recommendations
// can improve without a backend personalization service.

actor LocalUserActivityRepository: UserActivityRepository {

    static let shared = LocalUserActivityRepository()

    private let defaults: UserDefaults
    private let storageKey = "gamepedia.user-activity.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadActivity() async -> UserActivity {
        loadStored().toEntity()
    }

    func recordViewed(game: Game) async {
        var stored = loadStored()
        stored.viewedItemIDs = prependUnique(game.id, to: stored.viewedItemIDs, limit: 100)
        stored.recentViewedGenres = prepend(game.genre, to: stored.recentViewedGenres, limit: 20)
        stored.recentViewedCategories = prepend(game.category, to: stored.recentViewedCategories, limit: 20)
        save(stored)
    }

    func recordLiked(game: Game) async {
        var stored = loadStored()
        stored.likedItemIDs = prependUnique(game.id, to: stored.likedItemIDs, limit: 100)
        stored.likedGenres = prepend(game.genre, to: stored.likedGenres, limit: 20)
        stored.likedCategories = prepend(game.category, to: stored.likedCategories, limit: 20)
        save(stored)
    }

    func recordRecommendationExposure(ids: [Int], at: Date) async {
        guard !ids.isEmpty else { return }

        var stored = loadStored()
        for id in ids {
            stored.exposedRecommendationIDs = prepend(id, to: stored.exposedRecommendationIDs, limit: 100)
            stored.exposureCountByItemID["\(id)", default: 0] += 1
            stored.lastExposedAtByItemID["\(id)"] = at
        }
        save(stored)
    }

    private func loadStored() -> StoredUserActivity {
        guard
            let data = defaults.data(forKey: storageKey),
            let stored = try? decoder.decode(StoredUserActivity.self, from: data)
        else {
            return StoredUserActivity()
        }
        return stored
    }

    private func save(_ stored: StoredUserActivity) {
        guard let data = try? encoder.encode(stored) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func prepend<T>(_ value: T, to values: [T], limit: Int) -> [T] {
        Array(([value] + values).prefix(limit))
    }

    private func prependUnique<T: Equatable>(_ value: T, to values: [T], limit: Int) -> [T] {
        let filtered = values.filter { $0 != value }
        return Array(([value] + filtered).prefix(limit))
    }
}

private struct StoredUserActivity: Codable {
    var viewedItemIDs: [Int] = []
    var likedItemIDs: [Int] = []
    var recentViewedGenres: [String] = []
    var recentViewedCategories: [String] = []
    var likedGenres: [String] = []
    var likedCategories: [String] = []
    var exposedRecommendationIDs: [Int] = []
    var exposureCountByItemID: [String: Int] = [:]
    var lastExposedAtByItemID: [String: Date] = [:]

    func toEntity() -> UserActivity {
        UserActivity(
            viewedItemIDs: viewedItemIDs,
            likedItemIDs: likedItemIDs,
            recentViewedGenres: recentViewedGenres,
            recentViewedCategories: recentViewedCategories,
            likedGenres: likedGenres,
            likedCategories: likedCategories,
            exposedRecommendationIDs: exposedRecommendationIDs,
            exposureCountByItemID: exposureCountByItemID.reduce(into: [:]) { result, entry in
                if let key = Int(entry.key) { result[key] = entry.value }
            },
            lastExposedAtByItemID: lastExposedAtByItemID.reduce(into: [:]) { result, entry in
                if let key = Int(entry.key) { result[key] = entry.value }
            }
        )
    }
}
