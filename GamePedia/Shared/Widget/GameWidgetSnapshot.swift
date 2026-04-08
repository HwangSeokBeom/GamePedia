import Foundation

enum GameWidgetKind {
    static let trendingGames = "TrendingGamesWidget"
    static let reviewPrompt = "ReviewPromptWidget"
}

struct TrendingGamesWidgetSnapshot: Codable, Hashable {
    struct Item: Codable, Hashable {
        let gameID: Int
        let title: String
        let genreText: String
        let ratingText: String?
        let coverImageURL: URL?
        let rank: Int
        let targetURL: URL?
    }

    let generatedAt: Date
    let items: [Item]
}

extension TrendingGamesWidgetSnapshot {
    static let placeholder = TrendingGamesWidgetSnapshot(
        generatedAt: .distantPast,
        items: [
            Item(
                gameID: 0,
                title: "인기 게임",
                genreText: "탭해서 확인",
                ratingText: nil,
                coverImageURL: nil,
                rank: 1,
                targetURL: nil
            ),
            Item(
                gameID: 0,
                title: "트렌딩 타이틀",
                genreText: "곧 표시됩니다",
                ratingText: nil,
                coverImageURL: nil,
                rank: 2,
                targetURL: nil
            ),
            Item(
                gameID: 0,
                title: "추천 목록",
                genreText: "데이터 로딩 중",
                ratingText: nil,
                coverImageURL: nil,
                rank: 3,
                targetURL: nil
            )
        ]
    )
}

struct ReviewPromptWidgetSnapshot: Codable, Hashable {
    enum State: String, Codable, Hashable {
        case ready
        case empty
        case loggedOut
    }

    struct Item: Codable, Hashable {
        let gameID: Int
        let title: String
        let subtitleText: String
        let coverImageURL: URL?
        let reviewTargetURL: URL?
    }

    let generatedAt: Date
    let state: State
    let headerTitle: String
    let headlineText: String
    let bodyText: String
    let ctaTitle: String?
    let targetURL: URL?
    let item: Item?
}

extension ReviewPromptWidgetSnapshot {
    static let placeholder = ReviewPromptWidgetSnapshot(
        generatedAt: .distantPast,
        state: .empty,
        headerTitle: "리뷰 남기기",
        headlineText: "찜한 게임이 없어요",
        bodyText: "인기 게임을 둘러보고 새 리뷰를 남겨보세요.",
        ctaTitle: nil,
        targetURL: nil,
        item: nil
    )
}
