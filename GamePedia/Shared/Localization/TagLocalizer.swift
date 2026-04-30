import Foundation

enum RecommendationTagLocalizer {
    private static let unknownLogLock = NSLock()
    private static var loggedUnknownKeys = Set<String>()

    private struct TagDefinition {
        let key: String
        let aliases: [String]
        let localized: [AppLanguage: String]
    }

    private struct ReasonDefinition {
        let key: String
        let aliases: [String]
        let localized: [AppLanguage: String]
    }

    private static let definitions: [TagDefinition] = [
        definition("personalized", aliases: ["personalized match", "personalized_match", "맞춤", "カスタム", "个性化"], ko: "맞춤", en: "Personalized", ja: "カスタム", zh: "个性化"),
        definition("good match", aliases: ["great match", "잘 맞음", "よく合う", "很匹配"], ko: "잘 맞음", en: "Good Match", ja: "よく合う", zh: "很匹配"),
        definition("high rated", aliases: ["highly rated", "high_rated", "고평점 취향", "高評価傾向", "高评分偏好"], ko: "고평점 취향", en: "High Rated", ja: "高評価傾向", zh: "高评分偏好"),
        definition("default ranking", aliases: ["fallback", "fallback ranking", "ai fallback", "default sort", "기본 정렬", "標準順", "默认排序"], ko: "기본 정렬", en: "Default Ranking", ja: "標準順", zh: "默认排序"),
        definition("relaxing", aliases: ["relax", "healing", "chill", "힐링", "癒やし", "治愈"], ko: "힐링", en: "Relaxing", ja: "癒やし", zh: "治愈"),
        definition("relaxing visual novel", aliases: ["healing visual novel", "힐링 비주얼 노벨", "癒やしビジュアルノベル", "治愈视觉小说"], ko: "힐링 비주얼 노벨", en: "Relaxing Visual Novel", ja: "癒やしビジュアルノベル", zh: "治愈视觉小说"),
        definition("short interactive story", aliases: ["short story game", "짧은 인터랙티브 스토리", "短編インタラクティブストーリー", "短篇互动故事"], ko: "짧은 인터랙티브 스토리", en: "Short Interactive Story", ja: "短編インタラクティブストーリー", zh: "短篇互动故事"),
        definition("interactive story", aliases: ["인터랙티브 스토리", "インタラクティブストーリー", "互动故事"], ko: "인터랙티브 스토리", en: "Interactive Story", ja: "インタラクティブストーリー", zh: "互动故事"),
        definition("visual novel", aliases: ["비주얼 노벨", "ビジュアルノベル", "视觉小说"], ko: "비주얼 노벨", en: "Visual Novel", ja: "ビジュアルノベル", zh: "视觉小说"),
        definition("kitchen", aliases: ["cooking", "cook", "요리", "料理", "烹饪"], ko: "요리", en: "Cooking", ja: "料理", zh: "烹饪"),
        definition("game", aliases: ["games", "게임", "ゲーム", "游戏"], ko: "게임", en: "Game", ja: "ゲーム", zh: "游戏"),
        definition("survival", aliases: ["생존", "サバイバル", "生存"], ko: "생존", en: "Survival", ja: "サバイバル", zh: "生存"),
        definition("builder", aliases: ["building", "construction", "빌더", "건설", "建築", "建造"], ko: "빌더", en: "Builder", ja: "ビルダー", zh: "建造"),
        definition("short session", aliases: ["short", "short sessions", "quick", "short play", "짧은 세션", "短時間", "短时游玩"], ko: "짧은 세션", en: "Short Session", ja: "短時間", zh: "短时游玩"),
        definition("singleplayer", aliases: ["single player", "solo", "싱글플레이", "シングルプレイ", "单人"], ko: "싱글플레이", en: "Singleplayer", ja: "シングルプレイ", zh: "单人"),
        definition("balanced", aliases: ["balance", "균형형", "バランス型", "均衡"], ko: "균형형", en: "Balanced", ja: "バランス型", zh: "均衡"),
        definition("low difficulty", aliases: ["low", "easygoing", "낮은 난이도", "低難度", "低难度"], ko: "낮은 난이도", en: "Low Difficulty", ja: "低難度", zh: "低难度"),
        definition("medium difficulty", aliases: ["medium", "normal", "보통 난이도", "普通難度", "中等难度"], ko: "보통 난이도", en: "Medium Difficulty", ja: "普通難度", zh: "中等难度"),
        definition("high difficulty", aliases: ["high", "hard", "높은 난이도", "高難度", "高难度"], ko: "높은 난이도", en: "High Difficulty", ja: "高難度", zh: "高难度"),
        definition("difficult", aliases: ["challenging", "어려움", "難しい", "困难"], ko: "어려움", en: "Difficult", ja: "難しい", zh: "困难"),
        definition("easy", aliases: ["쉬움", "簡単", "简单"], ko: "쉬움", en: "Easy", ja: "簡単", zh: "简单"),
        definition("indie", aliases: ["인디", "インディー", "独立"], ko: "인디", en: "Indie", ja: "インディー", zh: "独立"),
        definition("puzzle", aliases: ["퍼즐", "パズル", "解谜"], ko: "퍼즐", en: "Puzzle", ja: "パズル", zh: "解谜"),
        definition("rpg", aliases: ["role playing", "roleplaying", "role playing rpg", "role-playing", "role-playing rpg", "롤플레잉", "RPG", "角色扮演"], ko: "RPG", en: "RPG", ja: "RPG", zh: "RPG"),
        definition("adventure", aliases: ["어드벤처", "アドベンチャー", "冒险"], ko: "어드벤처", en: "Adventure", ja: "アドベンチャー", zh: "冒险"),
        definition("simulator", aliases: ["simulation", "sim", "시뮬레이션", "シミュレーション", "模拟"], ko: "시뮬레이션", en: "Simulation", ja: "シミュレーション", zh: "模拟"),
        definition("strategy", aliases: ["전략", "ストラテジー", "策略"], ko: "전략", en: "Strategy", ja: "ストラテジー", zh: "策略"),
        definition("action", aliases: ["액션", "アクション", "动作"], ko: "액션", en: "Action", ja: "アクション", zh: "动作"),
        definition("sports", aliases: ["sport", "스포츠", "スポーツ", "体育"], ko: "스포츠", en: "Sports", ja: "スポーツ", zh: "体育"),
        definition("story", aliases: ["narrative", "스토리", "物語", "剧情"], ko: "스토리", en: "Story", ja: "ストーリー", zh: "剧情"),
        definition("story rich", aliases: ["story-rich", "스토리 중심", "物語重視", "剧情丰富"], ko: "스토리 중심", en: "Story Rich", ja: "物語重視", zh: "剧情丰富"),
        definition("cozy", aliases: ["아늑한", "아늑함", "居心地がいい", "舒适"], ko: "아늑함", en: "Cozy", ja: "癒やし系", zh: "舒适"),
        definition("casual", aliases: ["캐주얼", "カジュアル", "休闲"], ko: "캐주얼", en: "Casual", ja: "カジュアル", zh: "休闲"),
        definition("multiplayer", aliases: ["multi player", "멀티플레이", "マルチプレイ", "多人"], ko: "멀티플레이", en: "Multiplayer", ja: "マルチプレイ", zh: "多人"),
        definition("co op", aliases: ["coop", "co-op", "cooperative", "협동", "協力", "合作"], ko: "협동", en: "Co-op", ja: "協力", zh: "合作"),
        definition("online co op", aliases: ["online coop", "online co-op", "온라인 협동", "オンライン協力", "在线合作"], ko: "온라인 협동", en: "Online Co-op", ja: "オンライン協力", zh: "在线合作"),
        definition("turn based", aliases: ["turn-based", "턴제", "ターン制", "回合制"], ko: "턴제", en: "Turn-Based", ja: "ターン制", zh: "回合制"),
        definition("hidden object", aliases: ["hidden-object", "숨은그림찾기", "アイテム探し", "找物"], ko: "숨은그림찾기", en: "Hidden Object", ja: "アイテム探し", zh: "找物"),
        definition("farming", aliases: ["farm", "농장", " farming sim", "農場", "农场"], ko: "농장", en: "Farming", ja: "農場", zh: "农场"),
        definition("crafting", aliases: ["craft", "제작", "クラフト", "制作"], ko: "제작", en: "Crafting", ja: "クラフト", zh: "制作"),
        definition("decoration", aliases: ["decorating", "꾸미기", "デコレーション", "装饰"], ko: "꾸미기", en: "Decorating", ja: "デコレーション", zh: "装饰"),
        definition("exploration", aliases: ["explore", "탐험", "探索"], ko: "탐험", en: "Exploration", ja: "探索", zh: "探索"),
        definition("platformer", aliases: ["platform", "플랫폼", "プラットフォーマー", "平台跳跃"], ko: "플랫포머", en: "Platformer", ja: "プラットフォーマー", zh: "平台跳跃"),
        definition("roguelike", aliases: ["rogue like", "roguelite", "로그라이크", "ローグライク", "Roguelike"], ko: "로그라이크", en: "Roguelike", ja: "ローグライク", zh: "Roguelike"),
        definition("shooter", aliases: ["shooting", "fps", "슈터", "シューティング", "射击"], ko: "슈터", en: "Shooter", ja: "シューティング", zh: "射击"),
        definition("fighting", aliases: ["격투", "格闘", "格斗"], ko: "격투", en: "Fighting", ja: "格闘", zh: "格斗"),
        definition("racing", aliases: ["race", "레이싱", "レース", "竞速"], ko: "레이싱", en: "Racing", ja: "レース", zh: "竞速"),
        definition("card", aliases: ["cards", "카드", "カード", "卡牌"], ko: "카드", en: "Card", ja: "カード", zh: "卡牌"),
        definition("horror", aliases: ["공포", "ホラー", "恐怖"], ko: "공포", en: "Horror", ja: "ホラー", zh: "恐怖"),
        definition("mystery", aliases: ["미스터리", "ミステリー", "悬疑"], ko: "미스터리", en: "Mystery", ja: "ミステリー", zh: "悬疑"),
        definition("open world", aliases: ["open-world", "오픈 월드", "オープンワールド", "开放世界"], ko: "오픈 월드", en: "Open World", ja: "オープンワールド", zh: "开放世界"),
        definition("pc", aliases: ["windows pc"], ko: "PC", en: "PC", ja: "PC", zh: "PC"),
        definition("windows", ko: "Windows", en: "Windows", ja: "Windows", zh: "Windows"),
        definition("linux", ko: "Linux", en: "Linux", ja: "Linux", zh: "Linux"),
        definition("mac", aliases: ["macos", "mac os"], ko: "Mac", en: "Mac", ja: "Mac", zh: "Mac")
    ]

    private static let canonicalKeyByNormalizedAlias: [String: String] = {
        var lookup: [String: String] = [:]
        definitions.forEach { definition in
            ([definition.key] + definition.aliases).forEach { alias in
                lookup[normalizedKey(for: alias)] = definition.key
            }
        }
        return lookup
    }()

    private static let localizedValuesByKey: [String: [AppLanguage: String]] = {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.key, $0.localized) })
    }()

    private static let reasonDefinitions: [ReasonDefinition] = [
        reasonDefinition(
            "genre match",
            aliases: ["자주 즐기는 장르와 잘 맞아요", "matches genres you often play", "よく遊ぶジャンルに合っています", "与你常玩的类型很匹配"],
            ko: "자주 즐기는 장르와 잘 맞아요",
            en: "Matches genres you often play",
            ja: "よく遊ぶジャンルに合っています",
            zh: "与你常玩的类型很匹配"
        )
    ]

    private static let reasonKeyByNormalizedAlias: [String: String] = {
        var lookup: [String: String] = [:]
        reasonDefinitions.forEach { definition in
            ([definition.key] + definition.aliases).forEach { alias in
                lookup[normalizedKey(for: alias)] = definition.key
            }
        }
        return lookup
    }()

    private static let localizedReasonValuesByKey: [String: [AppLanguage: String]] = {
        Dictionary(uniqueKeysWithValues: reasonDefinitions.map { ($0.key, $0.localized) })
    }()

    static func localizedTags(
        for rawTags: [String],
        language: AppLanguage = DefaultLanguageProvider.shared.currentLanguage,
        screen: String
    ) -> [String] {
        var seenRawKeys = Set<String>()

        return rawTags.compactMap { rawTag in
            let trimmedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTag.isEmpty else { return nil }

            let normalizedKey = normalizedKey(for: trimmedTag)
            guard !normalizedKey.isEmpty else { return nil }
            let deduplicationKey = canonicalKeyByNormalizedAlias[normalizedKey] ?? normalizedKey
            guard seenRawKeys.insert(deduplicationKey).inserted else { return nil }

            return localizedTag(
                for: trimmedTag,
                normalizedKey: normalizedKey,
                language: language,
                screen: screen
            )
        }
    }

    static func localizedDisplayTags(
        rawTags: [String],
        genres: [String] = [],
        themes: [String] = [],
        keywords: [String] = [],
        locale: Locale = .current,
        maxCount: Int = 4
    ) -> [String] {
        localizedDisplayTags(
            rawTags: rawTags,
            genres: genres,
            themes: themes,
            keywords: keywords,
            language: AppLanguage.from(languageCode: locale.identifier),
            maxCount: maxCount,
            screen: "RecommendationTagLocalizer"
        )
    }

    static func localizedDisplayTags(
        rawTags: [String],
        genres: [String] = [],
        themes: [String] = [],
        keywords: [String] = [],
        language: AppLanguage = DefaultLanguageProvider.shared.currentLanguage,
        maxCount: Int = 4,
        screen: String
    ) -> [String] {
        let groupedCandidates = [
            (rawTags, 10),
            (genres, 20),
            (themes, 30),
            (keywords, 40)
        ]
        var seenKeys = Set<String>()
        var localizedCandidates: [(priority: Int, order: Int, title: String)] = []
        var order = 0

        groupedCandidates.forEach { tags, sourcePriority in
            tags.forEach { rawTag in
                order += 1
                guard let preparedTag = preparedTag(from: rawTag) else { return }
                let normalizedKey = normalizedKey(for: preparedTag)
                guard !normalizedKey.isEmpty, !isPlaceholder(normalizedKey) else { return }

                let canonicalKey = canonicalKeyByNormalizedAlias[normalizedKey] ?? normalizedKey
                guard seenKeys.insert(canonicalKey).inserted else { return }

                let title = localizedTag(
                    for: preparedTag,
                    normalizedKey: normalizedKey,
                    language: language,
                    screen: screen
                )
                localizedCandidates.append((
                    priority: displayPriority(for: canonicalKey, sourcePriority: sourcePriority),
                    order: order,
                    title: title
                ))
            }
        }

        return localizedCandidates
            .sorted {
                if $0.priority == $1.priority {
                    return $0.order < $1.order
                }
                return $0.priority < $1.priority
            }
            .prefix(max(0, maxCount))
            .map(\.title)
    }

    static func localizedGenres(
        for rawGenres: [String],
        language: AppLanguage = DefaultLanguageProvider.shared.currentLanguage,
        screen: String
    ) -> [String] {
        localizedTags(for: rawGenres, language: language, screen: screen)
    }

    static func unknownFallbackCount(
        for rawTags: [String],
        language: AppLanguage = DefaultLanguageProvider.shared.currentLanguage
    ) -> Int {
        rawTags.reduce(into: 0) { count, rawTag in
            let trimmedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTag.isEmpty else { return }
            let normalizedKey = normalizedKey(for: trimmedTag)
            guard canonicalKeyByNormalizedAlias[normalizedKey] == nil else { return }
            if language == .korean, trimmedTag.containsKoreanText { return }
            count += 1
        }
    }

    static func localizedTag(
        for rawTag: String,
        language: AppLanguage = DefaultLanguageProvider.shared.currentLanguage,
        screen: String
    ) -> String {
        let trimmedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return trimmedTag }
        return localizedTag(
            for: trimmedTag,
            normalizedKey: normalizedKey(for: trimmedTag),
            language: language,
            screen: screen
        )
    }

    static func localizedKnownRecommendationReason(
        for rawReason: String,
        language: AppLanguage = DefaultLanguageProvider.shared.currentLanguage,
        screen: String
    ) -> String? {
        let trimmedReason = rawReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else { return nil }

        let normalizedKey = normalizedKey(for: trimmedReason)
        guard let canonicalKey = reasonKeyByNormalizedAlias[normalizedKey] else {
#if DEBUG
            logUnknownTag(rawTag: rawReason, normalizedKey: normalizedKey, screen: "\(screen).reason")
#endif
            return nil
        }

        return localizedReasonValuesByKey[canonicalKey]?[language]
            ?? localizedReasonValuesByKey[canonicalKey]?[.english]
    }

    static func normalizedKey(for rawTag: String) -> String {
        let camelSeparatedTag = rawTag
            .replacingOccurrences(
                of: "([a-z0-9])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "([A-Z]+)([A-Z][a-z])",
                with: "$1 $2",
                options: .regularExpression
            )
        let separators = CharacterSet.alphanumerics.inverted
        return camelSeparatedTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func preparedTag(from rawTag: String) -> String? {
        let trimmedTag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return nil }
        let normalizedKey = normalizedKey(for: trimmedTag)
        guard !isPlaceholder(normalizedKey) else { return nil }
        return trimmedTag
    }

    private static func isPlaceholder(_ normalizedKey: String) -> Bool {
        [
            "",
            "null",
            "nil",
            "undefined",
            "unknown",
            "n a",
            "na",
            "none"
        ].contains(normalizedKey)
    }

    private static func displayPriority(for canonicalKey: String, sourcePriority: Int) -> Int {
        switch canonicalKey {
        case "personalized", "good match", "high rated":
            return min(sourcePriority, 0)
        case "default ranking":
            return 90
        default:
            return sourcePriority
        }
    }

    private static func definition(
        _ key: String,
        aliases: [String] = [],
        ko: String,
        en: String,
        ja: String,
        zh: String
    ) -> TagDefinition {
        TagDefinition(
            key: normalizedKey(for: key),
            aliases: aliases,
            localized: [
                .korean: ko,
                .english: en,
                .japanese: ja,
                .chinese: zh
            ]
        )
    }

    private static func reasonDefinition(
        _ key: String,
        aliases: [String],
        ko: String,
        en: String,
        ja: String,
        zh: String
    ) -> ReasonDefinition {
        ReasonDefinition(
            key: normalizedKey(for: key),
            aliases: aliases,
            localized: [
                .korean: ko,
                .english: en,
                .japanese: ja,
                .chinese: zh
            ]
        )
    }

    private static func localizedTag(
        for rawTag: String,
        normalizedKey: String,
        language: AppLanguage,
        screen: String
    ) -> String {
        if let canonicalKey = canonicalKeyByNormalizedAlias[normalizedKey],
           let localizedTag = localizedValuesByKey[canonicalKey]?[language] ?? localizedValuesByKey[canonicalKey]?[.english] {
            return localizedTag
        }

        if language == .korean, rawTag.containsKoreanText {
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

typealias TagLocalizer = RecommendationTagLocalizer

private extension String {
    var containsKoreanText: Bool {
        unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(Int(scalar.value))
                || (0x1100...0x11FF).contains(Int(scalar.value))
                || (0x3130...0x318F).contains(Int(scalar.value))
        }
    }
}
