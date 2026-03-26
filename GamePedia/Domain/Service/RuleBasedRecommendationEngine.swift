import Foundation

// MARK: - RuleBasedRecommendationEngine

struct RuleBasedRecommendationEngine: RecommendationServing {

    func recommend(
        from candidates: [Game],
        activity: UserActivity,
        limit: Int,
        config: RecommendationConfig,
        now: Date
    ) -> [TodayRecommendation] {
        let likedIDs = Set(activity.likedItemIDs)
        let viewedIDs = Set(activity.viewedItemIDs)
        let filtered = candidates
            .uniquedByID()
            .filter { !likedIDs.contains($0.id) }

        let primaryPool: [Game]
        if config.excludeViewedItems {
            let unseen = filtered.filter { !viewedIDs.contains($0.id) }
            primaryPool = unseen.isEmpty ? filtered : unseen
        } else {
            primaryPool = filtered
        }

        guard !primaryPool.isEmpty else { return [] }

        let maxPopularity = max(primaryPool.map(\.popularity).max() ?? 0, 1)
        let recentGenreWeights = weightedFrequencyMap(for: activity.recentViewedGenres)
        let recentCategoryWeights = weightedFrequencyMap(for: activity.recentViewedCategories)
        let likedGenreWeights = weightedFrequencyMap(for: activity.likedGenres)
        let likedCategoryWeights = weightedFrequencyMap(for: activity.likedCategories)

        return primaryPool
            .map { game in
                let recentCategoryMatchScore = max(
                    weightedMatchScore(value: game.genre, weights: recentGenreWeights),
                    weightedMatchScore(value: game.category, weights: recentCategoryWeights)
                ) * config.recentCategoryMatchWeight

                let likedSimilarityScore = max(
                    weightedMatchScore(value: game.genre, weights: likedGenreWeights),
                    weightedMatchScore(value: game.category, weights: likedCategoryWeights)
                ) * config.likedSimilarityWeight

                let highRatingScore = min(max(game.rating / 5.0, 0), 1) * config.highRatingWeight
                let popularityScore = min(max(game.popularity / maxPopularity, 0), 1) * config.popularityWeight
                let freshnessScore = freshnessFactor(for: game.releaseDate, now: now) * config.freshnessWeight

                let exposurePenalty = exposurePenalty(
                    for: game.id,
                    activity: activity,
                    now: now
                ) * config.exposurePenaltyWeight

                let watchedPenalty = viewedIDs.contains(game.id) ? config.watchedPenaltyWeight : 0

                let breakdown = RecommendationScoreBreakdown(
                    recentCategoryMatchScore: recentCategoryMatchScore,
                    likedSimilarityScore: likedSimilarityScore,
                    highRatingScore: highRatingScore,
                    popularityScore: popularityScore,
                    freshnessScore: freshnessScore,
                    exposurePenalty: exposurePenalty,
                    watchedPenalty: watchedPenalty
                )

                let reasons = buildReasons(for: game, breakdown: breakdown)
                let primaryReason = reasons.max(by: { $0.weight < $1.weight })
                    ?? RecommendationReason(kind: .editorPick, message: "취향에 맞을 만한 작품이에요", weight: 0)

                return TodayRecommendation(
                    game: game,
                    score: breakdown.finalScore,
                    primaryReason: primaryReason,
                    reasons: reasons,
                    scoreBreakdown: breakdown,
                    source: .personalized
                )
            }
            .filter { $0.score > 0 }
            .sorted {
                if abs($0.score - $1.score) > 0.001 { return $0.score > $1.score }
                if abs($0.game.rating - $1.game.rating) > 0.001 { return $0.game.rating > $1.game.rating }
                return $0.game.popularity > $1.game.popularity
            }
            .prefix(limit)
            .map { $0 }
    }

    private func buildReasons(
        for game: Game,
        breakdown: RecommendationScoreBreakdown
    ) -> [RecommendationReason] {
        var reasons: [RecommendationReason] = []

        if breakdown.recentCategoryMatchScore > 0 {
            reasons.append(
                RecommendationReason(
                    kind: .recentCategoryMatch,
                    message: "최근 자주 본 \(game.genre) 장르예요",
                    weight: breakdown.recentCategoryMatchScore
                )
            )
        }

        if breakdown.likedSimilarityScore > 0 {
            reasons.append(
                RecommendationReason(
                    kind: .likedSimilarity,
                    message: "이전에 좋아요한 작품과 비슷해요",
                    weight: breakdown.likedSimilarityScore
                )
            )
        }

        if breakdown.highRatingScore > 0, game.rating >= 4.0 {
            reasons.append(
                RecommendationReason(
                    kind: .highRating,
                    message: "평점이 높은 작품이에요",
                    weight: breakdown.highRatingScore
                )
            )
        }

        if breakdown.popularityScore > 0, game.popularity > 0 {
            reasons.append(
                RecommendationReason(
                    kind: .popular,
                    message: "지금 인기 있는 콘텐츠예요",
                    weight: breakdown.popularityScore
                )
            )
        }

        if breakdown.freshnessScore > 0 {
            reasons.append(
                RecommendationReason(
                    kind: .freshness,
                    message: "최근 출시된 작품이에요",
                    weight: breakdown.freshnessScore
                )
            )
        }

        return reasons.sorted { $0.weight > $1.weight }
    }

    private func weightedFrequencyMap(for values: [String]) -> [String: Double] {
        guard !values.isEmpty else { return [:] }

        var result: [String: Double] = [:]
        let cappedValues = Array(values.prefix(12))
        let count = Double(cappedValues.count)

        for (index, value) in cappedValues.enumerated() {
            let recencyWeight = 1.0 - (Double(index) / max(count, 1)) * 0.5
            result[value, default: 0] += recencyWeight
        }

        return result
    }

    private func weightedMatchScore(value: String, weights: [String: Double]) -> Double {
        guard let maxWeight = weights.values.max(), maxWeight > 0 else { return 0 }
        return min(weights[value, default: 0] / maxWeight, 1)
    }

    private func freshnessFactor(for releaseDate: Date?, now: Date) -> Double {
        guard let releaseDate else { return 0.2 }
        let days = max(Calendar.current.dateComponents([.day], from: releaseDate, to: now).day ?? 0, 0)
        switch days {
        case 0...180:
            return 1.0
        case 181...365:
            return 0.75
        case 366...730:
            return 0.45
        default:
            return 0.15
        }
    }

    private func exposurePenalty(for itemID: Int, activity: UserActivity, now: Date) -> Double {
        let countPenalty = min(Double(activity.exposureCount(for: itemID)) / 3.0, 1.0)

        let recentExposurePenalty: Double
        if let lastExposedAt = activity.lastExposedAt(for: itemID) {
            let hours = max(now.timeIntervalSince(lastExposedAt) / 3600, 0)
            switch hours {
            case 0..<12:
                recentExposurePenalty = 1.0
            case 12..<24:
                recentExposurePenalty = 0.6
            case 24..<72:
                recentExposurePenalty = 0.3
            default:
                recentExposurePenalty = 0
            }
        } else {
            recentExposurePenalty = 0
        }

        return min(countPenalty + recentExposurePenalty, 1.5)
    }
}

private extension Array where Element == Game {
    func uniquedByID() -> [Game] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}
