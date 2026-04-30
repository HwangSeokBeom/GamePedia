import Foundation

enum TagLocalizer {
    private static let unknownLogLock = NSLock()
    private static var loggedUnknownKeys = Set<String>()

    private static let localizedTagsByNormalizedKey: [String: String] = [
        "relaxing": "힐링",
        "kitchen": "요리",
        "game": "게임",
        "survival": "생존",
        "builder": "빌더",
        "short": "짧은 세션",
        "short session": "짧은 세션",
        "singleplayer": "싱글플레이",
        "single player": "싱글플레이",
        "balanced": "균형형",
        "low": "낮은 난이도",
        "indie": "인디",
        "puzzle": "퍼즐",
        "rpg": "RPG",
        "role playing": "RPG",
        "role playing rpg": "RPG",
        "adventure": "어드벤처",
        "simulator": "시뮬레이션",
        "simulation": "시뮬레이션",
        "strategy": "전략",
        "action": "액션",
        "sports": "스포츠",
        "story": "스토리",
        "story rich": "스토리 중심",
        "cozy": "아늑한",
        "casual": "캐주얼",
        "multiplayer": "멀티플레이",
        "multi player": "멀티플레이",
        "co op": "협동",
        "coop": "협동",
        "online co op": "온라인 협동",
        "difficult": "어려움",
        "easy": "쉬움",
        "high": "높은 난이도",
        "medium": "보통 난이도",
        "pc": "PC",
        "windows": "Windows",
        "linux": "Linux",
        "mac": "Mac",
        "turn based": "턴제",
        "hidden object": "숨은그림찾기"
    ]

    static func localizedTags(for rawTags: [String], screen: String) -> [String] {
        var seenRawKeys = Set<String>()

        return rawTags.compactMap { rawTag in
            let trimmedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTag.isEmpty else { return nil }

            let normalizedKey = normalizedKey(for: trimmedTag)
            guard !normalizedKey.isEmpty else { return nil }
            guard seenRawKeys.insert(normalizedKey).inserted else { return nil }

            return localizedTag(for: trimmedTag, normalizedKey: normalizedKey, screen: screen)
        }
    }

    static func localizedTag(for rawTag: String, screen: String) -> String {
        let trimmedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return trimmedTag }
        return localizedTag(
            for: trimmedTag,
            normalizedKey: normalizedKey(for: trimmedTag),
            screen: screen
        )
    }

    static func normalizedKey(for rawTag: String) -> String {
        let separators = CharacterSet.alphanumerics.inverted
        return rawTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func localizedTag(for rawTag: String, normalizedKey: String, screen: String) -> String {
        if let localizedTag = localizedTagsByNormalizedKey[normalizedKey] {
            return localizedTag
        }

        if rawTag.containsKoreanText {
            return rawTag
        }

#if DEBUG
        logUnknownTag(rawTag: rawTag, normalizedKey: normalizedKey, screen: screen)
#endif
        return readableFallback(for: rawTag, normalizedKey: normalizedKey)
    }

#if DEBUG
    private static func logUnknownTag(rawTag: String, normalizedKey: String, screen: String) {
        let logKey = "\(screen)|\(normalizedKey)"
        unknownLogLock.lock()
        let shouldLog = loggedUnknownKeys.insert(logKey).inserted
        unknownLogLock.unlock()

        guard shouldLog else { return }
        print("[AIRecommendationTags] unknown tag=\(rawTag) normalized=\(normalizedKey) screen=\(screen)")
    }
#endif

    private static func readableFallback(for rawTag: String, normalizedKey: String) -> String {
        let words = normalizedKey.isEmpty ? [rawTag] : normalizedKey.components(separatedBy: " ")
        return words
            .filter { !$0.isEmpty }
            .map { word in
                switch word {
                case "pc":
                    return "PC"
                case "rpg":
                    return "RPG"
                default:
                    return word.prefix(1).uppercased() + word.dropFirst()
                }
            }
            .joined(separator: " ")
    }
}

private extension String {
    var containsKoreanText: Bool {
        unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(Int(scalar.value))
                || (0x1100...0x11FF).contains(Int(scalar.value))
                || (0x3130...0x318F).contains(Int(scalar.value))
        }
    }
}
