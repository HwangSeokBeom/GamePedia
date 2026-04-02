import Foundation

final class ProfileBadgeSelectionStore {
    static let shared = ProfileBadgeSelectionStore()

    static let availableBadgeTitles = [
        "Pro Reviewer",
        "RPG Lover",
        "Hardcore Gamer"
    ]

    static let titleKeyByTitle: [String: String] = [
        "Pro Reviewer": "pro_reviewer",
        "RPG Lover": "rpg_lover",
        "Hardcore Gamer": "hardcore_gamer"
    ]

    static let titleByTitleKey: [String: String] = Dictionary(
        uniqueKeysWithValues: titleKeyByTitle.map { ($1, $0) }
    )

    private let userDefaults: UserDefaults
    private let storageKeyPrefix = "profile.badges."

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadSelectedBadges(
        for userID: String,
        fallbackRecentlyPlayedCount: Int,
        fallbackReviewCount: Int,
        fallbackWishlistCount: Int
    ) -> [String] {
        let storageKey = storageKey(for: userID)
        if let storedTitles = userDefaults.array(forKey: storageKey) as? [String] {
            return Array(storedTitles.filter { Self.availableBadgeTitles.contains($0) }.prefix(1))
        }

        var defaultTitles: [String] = []
        if fallbackReviewCount > 0 {
            defaultTitles.append("Pro Reviewer")
        }
        if fallbackWishlistCount > 0 {
            defaultTitles.append("RPG Lover")
        }
        if fallbackRecentlyPlayedCount > 0 {
            defaultTitles.append("Hardcore Gamer")
        }

        if defaultTitles.isEmpty {
            defaultTitles = Array(Self.availableBadgeTitles.prefix(1))
        }

        return Array(defaultTitles.prefix(1))
    }

    func saveSelectedBadges(_ badgeTitles: [String], for userID: String) {
        let sanitizedTitles = Array(badgeTitles.filter { Self.availableBadgeTitles.contains($0) }.prefix(1))
        userDefaults.set(sanitizedTitles, forKey: storageKey(for: userID))
    }

    func selectedTitleKeys(for badgeTitles: [String]) -> [String] {
        Array(
            badgeTitles
                .compactMap { Self.titleKeyByTitle[$0] }
                .prefix(1)
        )
    }

    func selectedTitleKey(for badgeTitle: String?) -> String? {
        guard let badgeTitle else { return nil }
        return Self.titleKeyByTitle[badgeTitle]
    }

    func badgeTitle(for selectedTitleKey: String?) -> String? {
        guard let selectedTitleKey else { return nil }
        return Self.titleByTitleKey[selectedTitleKey]
    }

    private func storageKey(for userID: String) -> String {
        storageKeyPrefix + userID
    }
}
