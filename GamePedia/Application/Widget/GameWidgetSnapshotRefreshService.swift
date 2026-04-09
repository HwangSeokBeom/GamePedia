import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

protocol WidgetTimelineReloading {
    func reloadTimelines(ofKind kind: String)
}

private struct LiveWidgetTimelineReloader: WidgetTimelineReloading {
    func reloadTimelines(ofKind kind: String) {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
#endif
    }
}

final class GameWidgetSnapshotRefreshService {
    private enum Limits {
        static let recentViewedRecordLimit = 12
        static let recentViewedWidgetLimit = 4
        static let trendingWidgetLimit = 4
        static let reviewPromptLimit = 4
        static let myActivityRecentReviewLimit = 2
    }

    private let snapshotStore: any GameWidgetSnapshotStoring
    private let widgetReloader: any WidgetTimelineReloading
    private let authTokenProvider: () -> String?
    private let recentViewedRecordsProvider: () -> [RecentViewedGameRecord]
    private let trendingGamesProvider: () async throws -> [Game]
    private let favoriteEntriesProvider: () async throws -> [FavoriteGameEntry]
    private let reviewedGamesProvider: () async throws -> [ReviewedGame]
    private let profileSummaryProvider: () async throws -> UserProfile
    private let writtenReviewCountProvider: () async throws -> Int

    init(
        snapshotStore: any GameWidgetSnapshotStoring = GameWidgetSnapshotStore.shared,
        widgetReloader: any WidgetTimelineReloading = LiveWidgetTimelineReloader(),
        authTokenProvider: @escaping () -> String? = { APIClient.shared.userAuthToken },
        loadHomeFeedUseCase: LoadHomeFeedUseCase = .live(),
        fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase = FetchFavoriteGamesUseCase(
            fetchMyFavoritesUseCase: FetchMyFavoritesUseCase(
                favoriteRepository: DefaultFavoriteRepository()
            ),
            gameRepository: DefaultGameRepository()
        ),
        fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase = FetchMyReviewedGamesUseCase(
            fetchMyReviewsUseCase: FetchMyReviewsUseCase(
                reviewRepository: DefaultReviewRepository()
            ),
            gameRepository: DefaultGameRepository()
        ),
        fetchMyReviewsUseCase: FetchMyReviewsUseCase = FetchMyReviewsUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        apiClient: APIClient = .shared
    ) {
        self.snapshotStore = snapshotStore
        self.widgetReloader = widgetReloader
        self.authTokenProvider = authTokenProvider
        self.recentViewedRecordsProvider = {
            snapshotStore.loadRecentViewedRecords()
        }
        self.trendingGamesProvider = {
            let feed = try await loadHomeFeedUseCase.execute(filter: .default)
            return Array(feed.trendingGames.prefix(Limits.trendingWidgetLimit))
        }
        self.favoriteEntriesProvider = {
            try await fetchFavoriteGamesUseCase.execute(sort: .latest)
        }
        self.reviewedGamesProvider = {
            try await fetchMyReviewedGamesUseCase.execute(sort: .latest)
        }
        self.profileSummaryProvider = {
            let response = try await apiClient.request(.myProfile, as: CurrentUserProfileResponseDTO.self)
            return UserProfileMapper.toEntity(response.profile)
        }
        self.writtenReviewCountProvider = {
            try await fetchMyReviewsUseCase.execute(sort: .latest).count
        }
    }

    init(
        snapshotStore: any GameWidgetSnapshotStoring,
        widgetReloader: any WidgetTimelineReloading,
        authTokenProvider: @escaping () -> String?,
        recentViewedRecordsProvider: @escaping () -> [RecentViewedGameRecord],
        trendingGamesProvider: @escaping () async throws -> [Game],
        favoriteEntriesProvider: @escaping () async throws -> [FavoriteGameEntry],
        reviewedGamesProvider: @escaping () async throws -> [ReviewedGame],
        profileSummaryProvider: @escaping () async throws -> UserProfile,
        writtenReviewCountProvider: @escaping () async throws -> Int
    ) {
        self.snapshotStore = snapshotStore
        self.widgetReloader = widgetReloader
        self.authTokenProvider = authTokenProvider
        self.recentViewedRecordsProvider = recentViewedRecordsProvider
        self.trendingGamesProvider = trendingGamesProvider
        self.favoriteEntriesProvider = favoriteEntriesProvider
        self.reviewedGamesProvider = reviewedGamesProvider
        self.profileSummaryProvider = profileSummaryProvider
        self.writtenReviewCountProvider = writtenReviewCountProvider
    }

    func refresh(reason: String) {
        Task {
            await refreshNow(reason: reason)
        }
    }

    func refreshNow(reason: String) async {
        switch reason {
        case "recentViewedDidChange":
            refreshRecentViewed(reason: reason)
        case "favoriteDidChange":
            await refreshReviewPrompt(reason: reason)
            await refreshMyActivity(reason: reason)
        case "reviewDidChange":
            await refreshReviewPrompt(reason: reason)
            await refreshMyActivity(reason: reason)
        default:
            refreshRecentViewed(reason: reason)
            await refreshTrendingGames(reason: reason)
            await refreshReviewPrompt(reason: reason)
            await refreshMyActivity(reason: reason)
        }
    }

    private func refreshRecentViewed(reason: String) {
        let records = Array(recentViewedRecordsProvider().prefix(Limits.recentViewedWidgetLimit))

        guard records.isEmpty == false else {
            snapshotStore.saveRecentViewed(.empty)
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.recentViewed)
            print("[WidgetSnapshot] recentViewedSaved state=empty trigger=\(reason)")
            return
        }

        let snapshot = RecentViewedWidgetSnapshot(
            generatedAt: Date(),
            state: .ready,
            headerTitle: "최근 본 게임",
            headlineText: "",
            bodyText: "",
            targetURL: records.first?.targetURL,
            items: records.map { record in
                RecentViewedWidgetSnapshot.Item(
                    gameID: record.gameID,
                    title: record.title,
                    genreText: record.genreText,
                    ratingText: record.ratingText,
                    coverImageURL: record.coverImageURL,
                    viewedAt: record.viewedAt,
                    viewedRelativeText: Self.relativeDateText(for: record.viewedAt),
                    targetURL: record.targetURL
                )
            }
        )
        snapshotStore.saveRecentViewed(snapshot)
        widgetReloader.reloadTimelines(ofKind: GameWidgetKind.recentViewed)
        print("[WidgetSnapshot] recentViewedSaved count=\(snapshot.items.count) trigger=\(reason)")
    }

    private func refreshTrendingGames(reason: String) async {
        do {
            let games = try await trendingGamesProvider()
            let items = games.prefix(Limits.trendingWidgetLimit).enumerated().map { index, game in
                TrendingGamesWidgetSnapshot.Item(
                    gameID: game.id,
                    title: game.displayTitle,
                    genreText: game.genre,
                    ratingText: game.formattedRating == "—" ? nil : game.formattedRating,
                    coverImageURL: game.coverImageURL,
                    rank: index + 1,
                    targetURL: WidgetDeepLink.game(game.id).url
                )
            }

            guard !items.isEmpty else {
                print("[WidgetSnapshot] trendingSkipped reason=emptyData trigger=\(reason)")
                return
            }

            snapshotStore.saveTrendingGames(
                TrendingGamesWidgetSnapshot(
                    generatedAt: Date(),
                    items: items
                )
            )
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.trendingGames)
            print("[WidgetSnapshot] trendingSaved count=\(items.count) trigger=\(reason)")
        } catch {
            print("[WidgetSnapshot] trendingFailed trigger=\(reason) error=\(error.localizedDescription)")
        }
    }

    private func refreshReviewPrompt(reason: String) async {
        guard authTokenProvider()?.isEmpty == false else {
            snapshotStore.saveReviewPrompt(Self.loggedOutReviewPromptSnapshot())
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.reviewPrompt)
            print("[WidgetSnapshot] reviewPromptSaved state=loggedOut trigger=\(reason)")
            return
        }

        do {
            let favorites = try await favoriteEntriesProvider()
            let reviewedGameIDs = Set(try await reviewedGamesProvider().map(\.gameId))
            let candidateEntries = favorites
                .filter { reviewedGameIDs.contains($0.game.id) == false }
                .prefix(Limits.reviewPromptLimit)

            guard candidateEntries.isEmpty == false else {
                snapshotStore.saveReviewPrompt(Self.emptyReviewPromptSnapshot())
                widgetReloader.reloadTimelines(ofKind: GameWidgetKind.reviewPrompt)
                print("[WidgetSnapshot] reviewPromptSaved state=empty trigger=\(reason)")
                return
            }

            let items = candidateEntries.map { entry in
                ReviewPromptWidgetSnapshot.Item(
                    gameID: entry.game.id,
                    title: entry.game.displayTitle,
                    subtitleText: Self.reviewPromptSubtitle(for: entry),
                    coverImageURL: entry.game.coverImageURL,
                    gameTargetURL: WidgetDeepLink.game(entry.game.id).url,
                    reviewTargetURL: WidgetDeepLink.reviewNew(entry.game.id).url
                )
            }

            let snapshot = ReviewPromptWidgetSnapshot(
                generatedAt: Date(),
                state: .ready,
                headerTitle: "리뷰 남기기",
                headlineText: items.first?.title ?? "리뷰 남기기",
                bodyText: "찜했지만 아직 리뷰를 남기지 않은 게임",
                ctaTitle: "리뷰 작성하기",
                targetURL: items.first?.reviewTargetURL,
                items: items,
                loggedOutContent: nil
            )
            snapshotStore.saveReviewPrompt(snapshot)
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.reviewPrompt)
            print("[WidgetSnapshot] reviewPromptSaved state=ready count=\(items.count) trigger=\(reason)")
        } catch {
            print("[WidgetSnapshot] reviewPromptFailed trigger=\(reason) error=\(error.localizedDescription)")
        }
    }

    private func refreshMyActivity(reason: String) async {
        guard authTokenProvider()?.isEmpty == false else {
            snapshotStore.saveMyActivity(Self.loggedOutMyActivitySnapshot())
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.myActivity)
            print("[WidgetSnapshot] myActivitySaved state=loggedOut trigger=\(reason)")
            return
        }

        do {
            async let profileTask = profileSummaryProvider()
            async let reviewedGamesTask = reviewedGamesProvider()
            async let writtenReviewCountTask = writtenReviewCountProvider()
            let profile = try await profileTask
            let reviewedGames = try await reviewedGamesTask
            let writtenReviewCount = (try? await writtenReviewCountTask) ?? profile.writtenReviewCount

#if DEBUG
            print(
                "[WidgetSnapshot][MyActivity] source " +
                "profileWrittenReviewCount=\(profile.writtenReviewCount) " +
                "fetchedWrittenReviewCount=\(writtenReviewCount) " +
                "reviewedGamesCount=\(reviewedGames.count) " +
                "reason=\(reason)"
            )
#endif

            let stats = Self.makeActivityStats(from: profile, writtenReviewCount: writtenReviewCount)
            let recentReviews = reviewedGames.prefix(Limits.myActivityRecentReviewLimit).map { reviewedGame in
                MyActivityWidgetSnapshot.ReviewItem(
                    reviewID: reviewedGame.reviewId,
                    gameID: reviewedGame.gameId,
                    gameTitle: reviewedGame.game.displayTitle,
                    ratingText: reviewedGame.game.formattedRating,
                    reviewText: Self.reviewPreviewText(for: reviewedGame),
                    coverImageURL: reviewedGame.game.coverImageURL,
                    relativeDateText: Self.reviewedGameDateText(for: reviewedGame),
                    targetURL: WidgetDeepLink.review(reviewedGame.reviewId).url
                )
            }

            guard stats.contains(where: { $0.valueText != "0" }) || recentReviews.isEmpty == false else {
                snapshotStore.saveMyActivity(.empty)
                widgetReloader.reloadTimelines(ofKind: GameWidgetKind.myActivity)
                print("[WidgetSnapshot] myActivitySaved state=empty trigger=\(reason)")
                return
            }

            let snapshot = MyActivityWidgetSnapshot(
                generatedAt: Date(),
                state: .ready,
                headerTitle: "내 활동",
                headlineText: "",
                bodyText: "",
                targetURL: WidgetDeepLink.profile.url,
                stats: stats,
                recentReviews: recentReviews,
                loggedOutContent: nil
            )
            snapshotStore.saveMyActivity(snapshot)
#if DEBUG
            let savedReviewCount = snapshot.stats.first(where: { $0.kind == .reviews })?.valueText ?? "nil"
            let storedReviewCount = snapshotStore.loadMyActivity()?.stats.first(where: { $0.kind == .reviews })?.valueText ?? "nil"
            print(
                "[WidgetSnapshot][MyActivity] saved " +
                "reviewCount=\(savedReviewCount) " +
                "storedReviewCount=\(storedReviewCount) " +
                "reason=\(reason)"
            )
#endif
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.myActivity)
            print("[WidgetSnapshot] myActivitySaved state=ready reviewCount=\(recentReviews.count) trigger=\(reason)")
        } catch {
            print("[WidgetSnapshot] myActivityFailed trigger=\(reason) error=\(error.localizedDescription)")
        }
    }

    private static func makeActivityStats(
        from profile: UserProfile,
        writtenReviewCount: Int
    ) -> [MyActivityWidgetSnapshot.StatItem] {
        [
            MyActivityWidgetSnapshot.StatItem(
                kind: .reviews,
                valueText: Self.countText(writtenReviewCount),
                labelText: "작성 리뷰"
            ),
            MyActivityWidgetSnapshot.StatItem(
                kind: .wishlist,
                valueText: Self.countText(profile.wishlistCount),
                labelText: "찜"
            ),
            MyActivityWidgetSnapshot.StatItem(
                kind: .likes,
                valueText: Self.countText(profile.likeCount),
                labelText: "좋아요"
            )
        ]
    }

    private static func countText(_ value: Int) -> String {
        String(max(0, value))
    }

    private static func reviewPromptSubtitle(for entry: FavoriteGameEntry) -> String {
        let genreText = entry.game.genre.trimmingCharacters(in: .whitespacesAndNewlines)
        let relativeText = entry.favorite.createdAt.map(relativeDateText(for:))

        if let relativeText, !genreText.isEmpty {
            return "\(genreText) · 찜 \(relativeText)"
        }

        if !genreText.isEmpty {
            return genreText
        }

        return "찜한 게임인데 아직 리뷰가 없어요"
    }

    private static func reviewPreviewText(for reviewedGame: ReviewedGame) -> String {
        let trimmedText = reviewedGame.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return "리뷰를 확인해보세요" }
        return "\"\(trimmedText)\""
    }

    private static func reviewedGameDateText(for reviewedGame: ReviewedGame) -> String {
        let relativeText = reviewedGame.createdAt.toRelativeDateString()
        return relativeText.isEmpty ? "최근 작성" : "\(relativeText) 작성"
    }

    private static func relativeDateText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func emptyReviewPromptSnapshot() -> ReviewPromptWidgetSnapshot {
        ReviewPromptWidgetSnapshot(
            generatedAt: Date(),
            state: .empty,
            headerTitle: "리뷰 남기기",
            headlineText: "리뷰할 찜 게임이 없어요",
            bodyText: "인기 게임을 둘러보고 새 리뷰를 남겨보세요.",
            ctaTitle: nil,
            targetURL: WidgetDeepLink.trending.url,
            items: [],
            loggedOutContent: nil
        )
    }

    private static func loggedOutReviewPromptSnapshot() -> ReviewPromptWidgetSnapshot {
        ReviewPromptWidgetSnapshot(
            generatedAt: Date(),
            state: .loggedOut,
            headerTitle: "리뷰 남기기",
            headlineText: WidgetLoggedOutContent.placeholder.headlineText,
            bodyText: WidgetLoggedOutContent.placeholder.bodyText,
            ctaTitle: WidgetLoggedOutContent.placeholder.ctaTitle,
            targetURL: WidgetLoggedOutContent.placeholder.targetURL,
            items: [],
            loggedOutContent: .placeholder
        )
    }

    private static func loggedOutMyActivitySnapshot() -> MyActivityWidgetSnapshot {
        MyActivityWidgetSnapshot(
            generatedAt: Date(),
            state: .loggedOut,
            headerTitle: "내 활동",
            headlineText: WidgetLoggedOutContent.placeholder.headlineText,
            bodyText: WidgetLoggedOutContent.placeholder.bodyText,
            targetURL: WidgetLoggedOutContent.placeholder.targetURL,
            stats: [],
            recentReviews: [],
            loggedOutContent: .placeholder
        )
    }
}
