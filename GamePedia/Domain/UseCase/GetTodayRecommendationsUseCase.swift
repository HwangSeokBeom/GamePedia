import Foundation

final class GetTodayRecommendationsUseCase {

    private let activityRepository: any UserActivityRepository
    private let recommendationEngine: any RecommendationServing
    private let logger: any RecommendationEventLogger
    private let config: RecommendationConfig
    private let dateProvider: () -> Date

    init(
        activityRepository: any UserActivityRepository,
        recommendationEngine: any RecommendationServing,
        logger: any RecommendationEventLogger,
        config: RecommendationConfig = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.activityRepository = activityRepository
        self.recommendationEngine = recommendationEngine
        self.logger = logger
        self.config = config
        self.dateProvider = dateProvider
    }

    func execute(
        candidates: [Game],
        fallbackPool: [Game],
        limit: Int = 5
    ) async -> RecommendationResult {
        let activity = await activityRepository.loadActivity()
        let now = dateProvider()

        let personalized = recommendationEngine.recommend(
            from: candidates,
            activity: activity,
            limit: limit,
            config: config,
            now: now
        )

        let result: RecommendationResult
        if activity.hasPersonalizationSignals, !personalized.isEmpty {
            result = RecommendationResult(items: personalized, source: .personalized)
        } else {
            result = makeFallbackRecommendations(from: fallbackPool, activity: activity, limit: limit)
        }

        await activityRepository.recordRecommendationExposure(
            ids: result.items.map(\.game.id),
            at: now
        )
        await logger.logImpression(items: result.items, source: result.source, at: now)
        return result
    }

    private func makeFallbackRecommendations(
        from games: [Game],
        activity: UserActivity,
        limit: Int
    ) -> RecommendationResult {
        let fallbackCandidates = filteredFallbackCandidates(from: games, activity: activity)
        guard !fallbackCandidates.isEmpty else {
            return RecommendationResult(items: [], source: .fallback(.editorPick))
        }

        if fallbackCandidates.contains(where: { $0.popularity > 0 }) {
            let items = fallbackCandidates
                .sorted {
                    if abs($0.popularity - $1.popularity) > 0.001 { return $0.popularity > $1.popularity }
                    return $0.rating > $1.rating
                }
                .prefix(limit)
                .map {
                    makeFallbackItem(
                        game: $0,
                        source: .fallback(.popular),
                        primary: RecommendationReason(
                            kind: .popular,
                            message: "지금 인기 있는 콘텐츠예요",
                            weight: $0.popularity
                        )
                    )
                }
            return RecommendationResult(items: items, source: .fallback(.popular))
        }

        if fallbackCandidates.contains(where: { $0.releaseDate != nil }) {
            let items = fallbackCandidates
                .sorted {
                    ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast)
                }
                .prefix(limit)
                .map {
                    makeFallbackItem(
                        game: $0,
                        source: .fallback(.latest),
                        primary: RecommendationReason(
                            kind: .freshness,
                            message: "최근 출시된 작품이에요",
                            weight: $0.releaseDate?.timeIntervalSince1970 ?? 0
                        )
                    )
                }
            return RecommendationResult(items: items, source: .fallback(.latest))
        }

        let items = fallbackCandidates
            .sorted {
                if abs($0.rating - $1.rating) > 0.001 { return $0.rating > $1.rating }
                return $0.reviewCount > $1.reviewCount
            }
            .prefix(limit)
            .map {
                makeFallbackItem(
                    game: $0,
                    source: .fallback(.editorPick),
                    primary: RecommendationReason(
                        kind: .editorPick,
                        message: "에디터 픽으로 준비했어요",
                        weight: $0.rating
                    )
                )
            }
        return RecommendationResult(items: items, source: .fallback(.editorPick))
    }

    private func filteredFallbackCandidates(from games: [Game], activity: UserActivity) -> [Game] {
        let blockedIDs = Set(activity.viewedItemIDs).union(activity.likedItemIDs)
        let unique = games.uniquedByID()
        let unseen = unique.filter { !blockedIDs.contains($0.id) }
        return unseen.isEmpty ? unique : unseen
    }

    private func makeFallbackItem(
        game: Game,
        source: RecommendationSource,
        primary: RecommendationReason
    ) -> TodayRecommendation {
        let breakdown = RecommendationScoreBreakdown(
            recentCategoryMatchScore: 0,
            likedSimilarityScore: 0,
            highRatingScore: primary.kind == .highRating ? primary.weight : 0,
            popularityScore: primary.kind == .popular ? primary.weight : 0,
            freshnessScore: primary.kind == .freshness ? primary.weight : 0,
            exposurePenalty: 0,
            watchedPenalty: 0
        )
        return TodayRecommendation(
            game: game,
            score: breakdown.finalScore,
            primaryReason: primary,
            reasons: [primary],
            scoreBreakdown: breakdown,
            source: source
        )
    }
}

private extension Array where Element == Game {
    func uniquedByID() -> [Game] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}
