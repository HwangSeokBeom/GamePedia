import Foundation

private enum GameWidgetSnapshotURL {
    static let trending = URL(string: "gamepedia://trending")!
    static let profile = URL(string: "gamepedia://profile")!
    static let login = URL(string: "gamepedia://login")!

    static func game(_ gameID: Int) -> URL {
        URL(string: "gamepedia://game/\(gameID)")!
    }

    static func review(_ reviewID: String) -> URL {
        URL(string: "gamepedia://review/\(reviewID)")!
    }
}

enum GameWidgetKind {
    static let recentViewed = "RecentViewedGamesWidget"
    static let trendingGames = "TrendingGamesWidget"
    static let myActivity = "MyActivityWidget"
    static let reviewPrompt = "ReviewPromptWidget"
}

struct WidgetLoggedOutContent: Codable, Hashable {
    let brandTitle: String
    let headlineText: String
    let bodyText: String
    let ctaTitle: String
    let targetURL: URL?
}

extension WidgetLoggedOutContent {
    static let placeholder = WidgetLoggedOutContent(
        brandTitle: "GamePedia",
        headlineText: "로그인이 필요해요",
        bodyText: "로그인하면 맞춤 게임 정보를 볼 수 있어요",
        ctaTitle: "로그인하기",
        targetURL: GameWidgetSnapshotURL.login
    )
}

struct RecentViewedGameRecord: Codable, Hashable, Identifiable {
    let gameID: Int
    let title: String
    let genreText: String
    let ratingText: String?
    let coverImageURL: URL?
    let viewedAt: Date

    var id: Int { gameID }
    var targetURL: URL { GameWidgetSnapshotURL.game(gameID) }
}

struct RecentViewedWidgetSnapshot: Codable, Hashable {
    enum State: String, Codable, Hashable {
        case ready
        case empty
    }

    struct Item: Codable, Hashable, Identifiable {
        let gameID: Int
        let title: String
        let genreText: String
        let ratingText: String?
        let coverImageURL: URL?
        let coverImageKey: String?
        let viewedAt: Date
        let viewedRelativeText: String
        let targetURL: URL?

        var id: Int { gameID }
    }

    let generatedAt: Date
    let state: State
    let headerTitle: String
    let headlineText: String
    let bodyText: String
    let targetURL: URL?
    let items: [Item]
}

extension RecentViewedWidgetSnapshot {
    static let placeholder = RecentViewedWidgetSnapshot(
        generatedAt: .distantPast,
        state: .ready,
        headerTitle: "최근 본 게임",
        headlineText: "",
        bodyText: "",
        targetURL: GameWidgetSnapshotURL.trending,
        items: [
            Item(
                gameID: -1,
                title: "엘든 링",
                genreText: "액션 RPG",
                ratingText: "4.8",
                coverImageURL: nil,
                coverImageKey: nil,
                viewedAt: .distantPast,
                viewedRelativeText: "방금 전",
                targetURL: nil
            ),
            Item(
                gameID: -2,
                title: "발더스 게이트 3",
                genreText: "RPG",
                ratingText: "4.9",
                coverImageURL: nil,
                coverImageKey: nil,
                viewedAt: .distantPast,
                viewedRelativeText: "1시간 전",
                targetURL: nil
            ),
            Item(
                gameID: -3,
                title: "사이버펑크 2077",
                genreText: "오픈월드",
                ratingText: "4.6",
                coverImageURL: nil,
                coverImageKey: nil,
                viewedAt: .distantPast,
                viewedRelativeText: "어제",
                targetURL: nil
            ),
            Item(
                gameID: -4,
                title: "젤다",
                genreText: "어드벤처",
                ratingText: "4.7",
                coverImageURL: nil,
                coverImageKey: nil,
                viewedAt: .distantPast,
                viewedRelativeText: "2일 전",
                targetURL: nil
            )
        ]
    )

    static let empty = RecentViewedWidgetSnapshot(
        generatedAt: .distantPast,
        state: .empty,
        headerTitle: "최근 본 게임",
        headlineText: "아직 본 게임이 없어요",
        bodyText: "게임을 탐색하고 여기서 빠르게 확인하세요",
        targetURL: GameWidgetSnapshotURL.trending,
        items: []
    )
}

struct TrendingGamesWidgetSnapshot: Codable, Hashable {
    struct Item: Codable, Hashable, Identifiable {
        let gameID: Int
        let title: String
        let genreText: String
        let ratingText: String?
        let coverImageURL: URL?
        let coverImageKey: String?
        let rank: Int
        let targetURL: URL?

        var id: String {
            if gameID != 0 {
                return String(gameID)
            }

            if let targetURL {
                return targetURL.absoluteString
            }

            return title
        }
    }

    let generatedAt: Date
    let items: [Item]
}

extension TrendingGamesWidgetSnapshot {
    static let placeholder = TrendingGamesWidgetSnapshot(
        generatedAt: .distantPast,
        items: [
            Item(
                gameID: -1,
                title: "인기 게임",
                genreText: "탭해서 확인",
                ratingText: nil,
                coverImageURL: nil,
                coverImageKey: nil,
                rank: 1,
                targetURL: nil
            ),
            Item(
                gameID: -2,
                title: "트렌딩 타이틀",
                genreText: "곧 표시됩니다",
                ratingText: nil,
                coverImageURL: nil,
                coverImageKey: nil,
                rank: 2,
                targetURL: nil
            ),
            Item(
                gameID: -3,
                title: "추천 목록",
                genreText: "데이터 로딩 중",
                ratingText: nil,
                coverImageURL: nil,
                coverImageKey: nil,
                rank: 3,
                targetURL: nil
            ),
            Item(
                gameID: -4,
                title: "주목할 타이틀",
                genreText: "불러오는 중",
                ratingText: nil,
                coverImageURL: nil,
                coverImageKey: nil,
                rank: 4,
                targetURL: nil
            )
        ]
    )
}

struct MyActivityWidgetSnapshot: Codable, Hashable {
    enum State: String, Codable, Hashable {
        case ready
        case empty
        case loggedOut
    }

    struct StatItem: Codable, Hashable, Identifiable {
        enum Kind: String, Codable, Hashable {
            case reviews
            case wishlist
            case likes
        }

        let kind: Kind
        let valueText: String
        let labelText: String

        var id: String { kind.rawValue }
    }

    struct ReviewItem: Codable, Hashable, Identifiable {
        let reviewID: String
        let gameID: Int
        let gameTitle: String
        let ratingText: String
        let reviewText: String
        let coverImageURL: URL?
        let coverImageKey: String?
        let relativeDateText: String
        let targetURL: URL?

        var id: String { reviewID }
    }

    let generatedAt: Date
    let state: State
    let headerTitle: String
    let headlineText: String
    let bodyText: String
    let targetURL: URL?
    let stats: [StatItem]
    let recentReviews: [ReviewItem]
    let loggedOutContent: WidgetLoggedOutContent?

    var featuredReview: ReviewItem? {
        recentReviews.first
    }
}

extension MyActivityWidgetSnapshot {
    static let placeholder = MyActivityWidgetSnapshot(
        generatedAt: .distantPast,
        state: .ready,
        headerTitle: "내 활동",
        headlineText: "",
        bodyText: "",
        targetURL: GameWidgetSnapshotURL.profile,
        stats: [
            StatItem(kind: .reviews, valueText: "12", labelText: "작성 리뷰"),
            StatItem(kind: .wishlist, valueText: "8", labelText: "찜"),
            StatItem(kind: .likes, valueText: "34", labelText: "좋아요")
        ],
        recentReviews: [
            ReviewItem(
                reviewID: "placeholder-review-1",
                gameID: 1,
                gameTitle: "엘든 링 DLC",
                ratingText: "4.8",
                reviewText: "\"역대 최고의 확장판...\"",
                coverImageURL: nil,
                coverImageKey: nil,
                relativeDateText: "3일 전 작성",
                targetURL: GameWidgetSnapshotURL.review("placeholder-review-1")
            ),
            ReviewItem(
                reviewID: "placeholder-review-2",
                gameID: 2,
                gameTitle: "발더스 게이트 3",
                ratingText: "4.9",
                reviewText: "\"CRPG의 새로운 기준...\"",
                coverImageURL: nil,
                coverImageKey: nil,
                relativeDateText: "5일 전 작성",
                targetURL: GameWidgetSnapshotURL.review("placeholder-review-2")
            )
        ],
        loggedOutContent: nil
    )

    static let empty = MyActivityWidgetSnapshot(
        generatedAt: .distantPast,
        state: .empty,
        headerTitle: "내 활동",
        headlineText: "아직 활동이 없어요",
        bodyText: "게임을 찜하거나 리뷰를 남겨보세요",
        targetURL: GameWidgetSnapshotURL.trending,
        stats: [],
        recentReviews: [],
        loggedOutContent: nil
    )
}

struct ReviewPromptWidgetSnapshot: Codable, Hashable {
    enum State: String, Codable, Hashable {
        case ready
        case empty
        case loggedOut
    }

    struct Item: Codable, Hashable, Identifiable {
        let gameID: Int
        let title: String
        let subtitleText: String
        let coverImageURL: URL?
        let coverImageKey: String?
        let gameTargetURL: URL?
        let reviewTargetURL: URL?

        var id: Int { gameID }
    }

    let generatedAt: Date
    let state: State
    let headerTitle: String
    let headlineText: String
    let bodyText: String
    let ctaTitle: String?
    let targetURL: URL?
    let items: [Item]
    let loggedOutContent: WidgetLoggedOutContent?

    var item: Item? {
        items.first
    }
}

extension ReviewPromptWidgetSnapshot {
    static let placeholder = ReviewPromptWidgetSnapshot(
        generatedAt: .distantPast,
        state: .empty,
        headerTitle: "리뷰 남기기",
        headlineText: "리뷰할 찜 게임이 없어요",
        bodyText: "인기 게임을 둘러보고 새 리뷰를 남겨보세요.",
        ctaTitle: nil,
        targetURL: nil,
        items: [],
        loggedOutContent: nil
    )
}
