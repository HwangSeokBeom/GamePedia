import Foundation

enum LibraryRoute {
    case showGameDetail(Int)
    case showSteamLink(URL)
    case showRecentlyPlayed
    case showReviewed
}

enum LibrarySectionKind: Int, CaseIterable, Hashable {
    case recentlyPlayed
    case playing
    case wishlist
    case reviewed

    var title: String {
        switch self {
        case .recentlyPlayed:
            return "최근 플레이한 게임"
        case .playing:
            return "플레이 중"
        case .wishlist:
            return "찜한 게임"
        case .reviewed:
            return "리뷰 작성함"
        }
    }

    var systemImageName: String {
        switch self {
        case .recentlyPlayed:
            return "clock.arrow.circlepath"
        case .playing:
            return "gamecontroller.fill"
        case .wishlist:
            return "heart.fill"
        case .reviewed:
            return "text.bubble.fill"
        }
    }
}

enum LibrarySectionLayoutStyle: Hashable {
    case recentCards
    case list
    case message
}

struct LibrarySectionViewState: Hashable {
    let kind: LibrarySectionKind
    let layoutStyle: LibrarySectionLayoutStyle
    let items: [LibraryCollectionItem]
    let showsSeeAll: Bool
}

enum LibraryCollectionItem: Hashable {
    case recentCard(LibraryRecentGameCardViewState)
    case row(LibraryGameRowViewState)
    case message(LibraryMessageViewState)
}

struct LibraryRecentGameCardViewState: Hashable {
    let identifier: LibraryGameIdentifier
    let title: String
    let metadataText: String
    let ratingText: String?
    let coverImageURL: URL?
    let badgeText: String
    let actionTitle: String?
    let isActionEnabled: Bool
}

struct LibraryGameRowViewState: Hashable {
    let identifier: LibraryGameIdentifier
    let title: String
    let subtitleText: String
    let metadataText: String
    let coverImageURL: URL?
    let ratingText: String?
    let trailingAction: LibraryRowTrailingAction?
}

enum LibraryRowTrailingAction: Hashable {
    case removeWishlist
}

struct LibraryMessageViewState: Hashable {
    let id: String
    let style: LibraryMessageStyle
    let title: String?
    let message: String
    let detailText: String?
    let buttonTitle: String?
    let action: LibraryMessageAction?
}

enum LibraryMessageStyle: Hashable {
    case banner
    case empty
    case error
}

enum LibraryMessageAction: Hashable {
    case connectSteam
    case retrySteamSync
}
