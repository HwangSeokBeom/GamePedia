#if DEBUG
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetDebugQAHelper {
    private enum EnvironmentKey {
        static let widgetSeed = "GAMEPEDIA_DEBUG_WIDGET_SEED"
        static let openURL = "GAMEPEDIA_DEBUG_OPEN_URL"
        static let skipSessionRefresh = "GAMEPEDIA_DEBUG_SKIP_SESSION_REFRESH"
    }

    private enum Seed: String {
        case sample = "sample"
        case loggedOut = "logged_out"
    }

    static var shouldSkipAutomaticSessionRefresh: Bool {
        currentSeed != nil || isTruthyEnvironmentValue(EnvironmentKey.skipSessionRefresh)
    }

    @discardableResult
    static func applyLaunchOverrides(
        snapshotStore: GameWidgetSnapshotStore = .shared
    ) -> URL? {
        if let currentSeed {
            switch currentSeed {
            case .sample:
                seedSampleSnapshots(snapshotStore: snapshotStore)
            case .loggedOut:
                seedLoggedOutSnapshots(snapshotStore: snapshotStore)
            }
        }

        guard let rawURL = ProcessInfo.processInfo.environment[EnvironmentKey.openURL],
              let launchURL = URL(string: rawURL) else {
            return nil
        }

        return launchURL
    }

    static func seedSampleSnapshots(
        snapshotStore: GameWidgetSnapshotStore = .shared,
        now: Date = Date()
    ) {
        let recentRecords = makeRecentViewedRecords(now: now)
        snapshotStore.saveRecentViewedRecords(recentRecords)
        snapshotStore.saveRecentViewed(
            RecentViewedWidgetSnapshot(
                generatedAt: now,
                state: .ready,
                headerTitle: "최근 본 게임",
                headlineText: "",
                bodyText: "",
                targetURL: recentRecords.first?.targetURL,
                items: recentRecords.prefix(4).map {
                    RecentViewedWidgetSnapshot.Item(
                        gameID: $0.gameID,
                        title: $0.title,
                        genreText: $0.genreText,
                        ratingText: $0.ratingText,
                        coverImageURL: $0.coverImageURL,
                        viewedAt: $0.viewedAt,
                        viewedRelativeText: relativeDateText(for: $0.viewedAt, referenceDate: now),
                        targetURL: $0.targetURL
                    )
                }
            )
        )

        let trendingItems = makeTrendingItems()
        snapshotStore.saveTrendingGames(
            TrendingGamesWidgetSnapshot(
                generatedAt: now,
                items: trendingItems
            )
        )

        snapshotStore.saveMyActivity(
            MyActivityWidgetSnapshot(
                generatedAt: now,
                state: .ready,
                headerTitle: "내 활동",
                headlineText: "",
                bodyText: "",
                targetURL: WidgetDeepLink.profile.url,
                stats: [
                    .init(kind: .reviews, valueText: "12", labelText: "리뷰"),
                    .init(kind: .wishlist, valueText: "8", labelText: "찜"),
                    .init(kind: .likes, valueText: "34", labelText: "좋아요")
                ],
                recentReviews: [
                    .init(
                        reviewID: "debug-review-1",
                        gameID: 201,
                        gameTitle: "엘든 링",
                        ratingText: "4.8",
                        reviewText: "\"몰입감이 압도적이에요.\"",
                        coverImageURL: URL(string: "https://example.com/debug-review-1.jpg"),
                        relativeDateText: "2일 전 작성",
                        targetURL: WidgetDeepLink.review("debug-review-1").url
                    ),
                    .init(
                        reviewID: "debug-review-2",
                        gameID: 202,
                        gameTitle: "하데스 2",
                        ratingText: "4.7",
                        reviewText: "\"전투 템포가 정말 좋아요.\"",
                        coverImageURL: URL(string: "https://example.com/debug-review-2.jpg"),
                        relativeDateText: "5일 전 작성",
                        targetURL: WidgetDeepLink.review("debug-review-2").url
                    )
                ],
                loggedOutContent: nil
            )
        )

        let reviewPromptItems = makeReviewPromptItems()
        snapshotStore.saveReviewPrompt(
            ReviewPromptWidgetSnapshot(
                generatedAt: now,
                state: .ready,
                headerTitle: "리뷰 남기기",
                headlineText: reviewPromptItems.first?.title ?? "리뷰 남기기",
                bodyText: "찜했지만 아직 리뷰를 남기지 않은 게임",
                ctaTitle: "리뷰 작성하기",
                targetURL: reviewPromptItems.first?.reviewTargetURL,
                items: reviewPromptItems,
                loggedOutContent: nil
            )
        )

        reloadAllWidgetKinds()
        print("[WidgetDebug] seeded preset=sample")
    }

    static func seedLoggedOutSnapshots(
        snapshotStore: GameWidgetSnapshotStore = .shared,
        now: Date = Date()
    ) {
        snapshotStore.saveRecentViewedRecords([])
        snapshotStore.saveRecentViewed(.empty)
        snapshotStore.saveTrendingGames(
            TrendingGamesWidgetSnapshot(
                generatedAt: now,
                items: makeTrendingItems()
            )
        )
        snapshotStore.saveMyActivity(
            MyActivityWidgetSnapshot(
                generatedAt: now,
                state: .loggedOut,
                headerTitle: "내 활동",
                headlineText: WidgetLoggedOutContent.placeholder.headlineText,
                bodyText: WidgetLoggedOutContent.placeholder.bodyText,
                targetURL: WidgetDeepLink.login.url,
                stats: [],
                recentReviews: [],
                loggedOutContent: .placeholder
            )
        )
        snapshotStore.saveReviewPrompt(
            ReviewPromptWidgetSnapshot(
                generatedAt: now,
                state: .loggedOut,
                headerTitle: "리뷰 남기기",
                headlineText: WidgetLoggedOutContent.placeholder.headlineText,
                bodyText: WidgetLoggedOutContent.placeholder.bodyText,
                ctaTitle: WidgetLoggedOutContent.placeholder.ctaTitle,
                targetURL: WidgetDeepLink.login.url,
                items: [],
                loggedOutContent: .placeholder
            )
        )

        reloadAllWidgetKinds()
        print("[WidgetDebug] seeded preset=logged_out")
    }

    private static var currentSeed: Seed? {
        guard let rawValue = ProcessInfo.processInfo.environment[EnvironmentKey.widgetSeed]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              rawValue.isEmpty == false else {
            return nil
        }

        return Seed(rawValue: rawValue)
    }

    private static func isTruthyEnvironmentValue(_ key: String) -> Bool {
        guard let rawValue = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }

        return ["1", "true", "yes", "y"].contains(rawValue)
    }

    private static func reloadAllWidgetKinds() {
#if canImport(WidgetKit)
        [
            GameWidgetKind.recentViewed,
            GameWidgetKind.trendingGames,
            GameWidgetKind.myActivity,
            GameWidgetKind.reviewPrompt
        ].forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
#endif
    }

    private static func relativeDateText(for date: Date, referenceDate: Date) -> String {
        let seconds = max(0, Int(referenceDate.timeIntervalSince(date)))
        if seconds < 60 {
            return "방금 전"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)분 전"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)시간 전"
        }

        return "\(hours / 24)일 전"
    }

    private static func makeRecentViewedRecords(now: Date) -> [RecentViewedGameRecord] {
        [
            RecentViewedGameRecord(
                gameID: 401,
                title: "엘든 링",
                genreText: "액션 RPG",
                ratingText: "4.8",
                coverImageURL: URL(string: "https://example.com/recent-1.jpg"),
                viewedAt: now.addingTimeInterval(-60 * 12)
            ),
            RecentViewedGameRecord(
                gameID: 402,
                title: "발더스 게이트 3",
                genreText: "CRPG",
                ratingText: "4.9",
                coverImageURL: URL(string: "https://example.com/recent-2.jpg"),
                viewedAt: now.addingTimeInterval(-60 * 60 * 3)
            ),
            RecentViewedGameRecord(
                gameID: 403,
                title: "사이버펑크 2077",
                genreText: "오픈월드",
                ratingText: "4.6",
                coverImageURL: URL(string: "https://example.com/recent-3.jpg"),
                viewedAt: now.addingTimeInterval(-60 * 60 * 24)
            ),
            RecentViewedGameRecord(
                gameID: 404,
                title: "젤다: 왕국의 눈물",
                genreText: "어드벤처",
                ratingText: "4.7",
                coverImageURL: URL(string: "https://example.com/recent-4.jpg"),
                viewedAt: now.addingTimeInterval(-60 * 60 * 36)
            )
        ]
    }

    private static func makeTrendingItems() -> [TrendingGamesWidgetSnapshot.Item] {
        [
            .init(
                gameID: 101,
                title: "클레르 옵스퀴르: 익스페디션 33",
                genreText: "턴제 RPG",
                ratingText: "4.9",
                coverImageURL: URL(string: "https://example.com/trending-1.jpg"),
                rank: 1,
                targetURL: WidgetDeepLink.game(101).url
            ),
            .init(
                gameID: 102,
                title: "하데스 2",
                genreText: "로그라이크",
                ratingText: "4.7",
                coverImageURL: URL(string: "https://example.com/trending-2.jpg"),
                rank: 2,
                targetURL: WidgetDeepLink.game(102).url
            ),
            .init(
                gameID: 103,
                title: "엘든 링",
                genreText: "액션 RPG",
                ratingText: "4.8",
                coverImageURL: URL(string: "https://example.com/trending-3.jpg"),
                rank: 3,
                targetURL: WidgetDeepLink.game(103).url
            ),
            .init(
                gameID: 104,
                title: "발더스 게이트 3",
                genreText: "CRPG",
                ratingText: "4.9",
                coverImageURL: URL(string: "https://example.com/trending-4.jpg"),
                rank: 4,
                targetURL: WidgetDeepLink.game(104).url
            )
        ]
    }

    private static func makeReviewPromptItems() -> [ReviewPromptWidgetSnapshot.Item] {
        [
            .init(
                gameID: 301,
                title: "엘든 링",
                subtitleText: "찜했지만 아직 리뷰를 남기지 않았어요",
                coverImageURL: URL(string: "https://example.com/review-prompt-1.jpg"),
                gameTargetURL: WidgetDeepLink.game(301).url,
                reviewTargetURL: WidgetDeepLink.reviewNew(301).url
            ),
            .init(
                gameID: 302,
                title: "하데스 2",
                subtitleText: "플레이 감상이 남아 있을 때 적어보세요",
                coverImageURL: URL(string: "https://example.com/review-prompt-2.jpg"),
                gameTargetURL: WidgetDeepLink.game(302).url,
                reviewTargetURL: WidgetDeepLink.reviewNew(302).url
            ),
            .init(
                gameID: 303,
                title: "발더스 게이트 3",
                subtitleText: "지금 한 줄만 남겨도 충분해요",
                coverImageURL: URL(string: "https://example.com/review-prompt-3.jpg"),
                gameTargetURL: WidgetDeepLink.game(303).url,
                reviewTargetURL: WidgetDeepLink.reviewNew(303).url
            ),
            .init(
                gameID: 304,
                title: "사이버펑크 2077",
                subtitleText: "최근 플레이 경험을 정리해보세요",
                coverImageURL: URL(string: "https://example.com/review-prompt-4.jpg"),
                gameTargetURL: WidgetDeepLink.game(304).url,
                reviewTargetURL: WidgetDeepLink.reviewNew(304).url
            )
        ]
    }
}
#endif
