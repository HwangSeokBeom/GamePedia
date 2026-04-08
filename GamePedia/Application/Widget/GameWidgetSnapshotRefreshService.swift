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
    private let snapshotStore: any GameWidgetSnapshotStoring
    private let widgetReloader: any WidgetTimelineReloading
    private let authTokenProvider: () -> String?
    private let trendingGamesProvider: () async throws -> [Game]
    private let favoriteEntriesProvider: () async throws -> [FavoriteGameEntry]
    private let reviewedGamesProvider: () async throws -> [ReviewedGame]

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
        )
    ) {
        self.snapshotStore = snapshotStore
        self.widgetReloader = widgetReloader
        self.authTokenProvider = authTokenProvider
        self.trendingGamesProvider = {
            let feed = try await loadHomeFeedUseCase.execute(filter: .default)
            return Array(feed.trendingGames.prefix(3))
        }
        self.favoriteEntriesProvider = {
            try await fetchFavoriteGamesUseCase.execute(sort: .latest)
        }
        self.reviewedGamesProvider = {
            try await fetchMyReviewedGamesUseCase.execute(sort: .latest)
        }
    }

    init(
        snapshotStore: any GameWidgetSnapshotStoring,
        widgetReloader: any WidgetTimelineReloading,
        authTokenProvider: @escaping () -> String?,
        trendingGamesProvider: @escaping () async throws -> [Game],
        favoriteEntriesProvider: @escaping () async throws -> [FavoriteGameEntry],
        reviewedGamesProvider: @escaping () async throws -> [ReviewedGame]
    ) {
        self.snapshotStore = snapshotStore
        self.widgetReloader = widgetReloader
        self.authTokenProvider = authTokenProvider
        self.trendingGamesProvider = trendingGamesProvider
        self.favoriteEntriesProvider = favoriteEntriesProvider
        self.reviewedGamesProvider = reviewedGamesProvider
    }

    func refresh(reason: String) {
        Task {
            await refreshNow(reason: reason)
        }
    }

    func refreshNow(reason: String) async {
        await refreshTrendingGames(reason: reason)
        await refreshReviewPrompt(reason: reason)
    }

    private func refreshTrendingGames(reason: String) async {
        do {
            let games = try await trendingGamesProvider()
            let items = games.prefix(3).enumerated().map { index, game in
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
            snapshotStore.saveReviewPrompt(Self.loggedOutSnapshot())
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.reviewPrompt)
            print("[WidgetSnapshot] reviewPromptSaved state=loggedOut trigger=\(reason)")
            return
        }

        do {
            let favorites = try await favoriteEntriesProvider()
            let reviewedGameIDs = Set(try await reviewedGamesProvider().map(\.gameId))

            guard let entry = favorites.first(where: { reviewedGameIDs.contains($0.game.id) == false }) else {
                snapshotStore.saveReviewPrompt(Self.emptySnapshot())
                widgetReloader.reloadTimelines(ofKind: GameWidgetKind.reviewPrompt)
                print("[WidgetSnapshot] reviewPromptSaved state=empty trigger=\(reason)")
                return
            }

            let item = ReviewPromptWidgetSnapshot.Item(
                gameID: entry.game.id,
                title: entry.game.displayTitle,
                subtitleText: Self.reviewPromptSubtitle(for: entry),
                coverImageURL: entry.game.coverImageURL,
                reviewTargetURL: WidgetDeepLink.reviewNew(entry.game.id).url
            )
            snapshotStore.saveReviewPrompt(
                ReviewPromptWidgetSnapshot(
                    generatedAt: Date(),
                    state: .ready,
                    headerTitle: "리뷰 남기기",
                    headlineText: item.title,
                    bodyText: item.subtitleText,
                    ctaTitle: "리뷰 작성하기",
                    targetURL: item.reviewTargetURL,
                    item: item
                )
            )
            widgetReloader.reloadTimelines(ofKind: GameWidgetKind.reviewPrompt)
            print("[WidgetSnapshot] reviewPromptSaved state=ready gameID=\(entry.game.id) trigger=\(reason)")
        } catch {
            print("[WidgetSnapshot] reviewPromptFailed trigger=\(reason) error=\(error.localizedDescription)")
        }
    }

    private static func reviewPromptSubtitle(for entry: FavoriteGameEntry) -> String {
        let genreText = entry.game.genre.trimmingCharacters(in: .whitespacesAndNewlines)
        let relativeText = entry.favorite.createdAt.map {
            RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
        }

        if let relativeText, !genreText.isEmpty {
            return "\(genreText) · 찜 \(relativeText)\n경험을 공유해보세요!"
        }

        if !genreText.isEmpty {
            return "\(genreText)\n경험을 공유해보세요!"
        }

        return "찜한 게임인데 아직 리뷰가 없어요.\n경험을 공유해보세요!"
    }

    private static func emptySnapshot() -> ReviewPromptWidgetSnapshot {
        ReviewPromptWidgetSnapshot(
            generatedAt: Date(),
            state: .empty,
            headerTitle: "리뷰 남기기",
            headlineText: "리뷰할 찜 게임이 없어요",
            bodyText: "인기 게임을 둘러보고 새 리뷰를 남겨보세요.",
            ctaTitle: nil,
            targetURL: WidgetDeepLink.trending.url,
            item: nil
        )
    }

    private static func loggedOutSnapshot() -> ReviewPromptWidgetSnapshot {
        ReviewPromptWidgetSnapshot(
            generatedAt: Date(),
            state: .loggedOut,
            headerTitle: "리뷰 남기기",
            headlineText: "로그인이 필요해요",
            bodyText: "로그인하면 위젯에서 바로 리뷰를 작성할 수 있어요.",
            ctaTitle: "로그인하기",
            targetURL: WidgetDeepLink.login.url,
            item: nil
        )
    }
}
