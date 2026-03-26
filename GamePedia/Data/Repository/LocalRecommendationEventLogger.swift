import Foundation

actor LocalRecommendationEventLogger: RecommendationEventLogger {

    static let shared = LocalRecommendationEventLogger()

    private let defaults: UserDefaults
    private let storageKey = "gamepedia.recommendation-impressions.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func logImpression(items: [TodayRecommendation], source: RecommendationSource, at: Date) async {
        guard !items.isEmpty else { return }

        var logs = loadLogs()
        logs.insert(
            StoredRecommendationImpression(
                itemIDs: items.map(\.game.id),
                source: source.storageValue,
                reasonKinds: items.map(\.primaryReason.kind.rawValue),
                createdAt: at
            ),
            at: 0
        )
        logs = Array(logs.prefix(100))
        save(logs)
    }

    private func loadLogs() -> [StoredRecommendationImpression] {
        guard
            let data = defaults.data(forKey: storageKey),
            let logs = try? decoder.decode([StoredRecommendationImpression].self, from: data)
        else {
            return []
        }
        return logs
    }

    private func save(_ logs: [StoredRecommendationImpression]) {
        guard let data = try? encoder.encode(logs) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private struct StoredRecommendationImpression: Codable {
    let itemIDs: [Int]
    let source: String
    let reasonKinds: [String]
    let createdAt: Date
}
