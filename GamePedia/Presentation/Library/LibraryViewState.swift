import Foundation

enum LibraryRoute {
    case showGameDetail(Int)
    case showSteamDetail(SteamFallbackGameDetailViewState)
    case showSteamLink(URL)
    case showSteamPrivacyGuide(URL)
    case showSectionList(LibrarySectionListRoute)
    case showReviewed
}

enum LibraryGameDetailDestination: Hashable {
    case igdb(Int)
    case steamFallback(SteamFallbackGameDetailViewState)
}

struct LibrarySectionListRoute: Hashable {
    let kind: LibrarySectionKind
    let layoutStyle: LibrarySectionLayoutStyle
    let items: [LibraryCollectionItem]
    let loadBehavior: LibrarySectionListLoadBehavior

    var title: String {
        kind.title
    }
}

enum LibrarySectionListLoadBehavior: Hashable {
    case staticPreview
    case recentlyPlayed
    case playing
    case ownedGames(sort: UserGameCollectionSortOption)
    case wishlist(sort: FavoriteSortOption)
    case reviewed(sort: ReviewSortOption)
    case friendRecommendations
    case playtimeRecommendations
}

enum LibrarySectionKind: Int, CaseIterable, Hashable {
    case recentlyPlayed
    case playing
    case owned
    case playtimeRecommendations
    case friendRecommendations
    case wishlist
    case reviewed

    static let displayOrder: [LibrarySectionKind] = [
        .recentlyPlayed,
        .playtimeRecommendations,
        .reviewed,
        .playing,
        .owned,
        .friendRecommendations,
        .wishlist
    ]

    var title: String {
        switch self {
        case .recentlyPlayed:
            return L10n.Library.Section.recentlyPlayedGames
        case .playing:
            return L10n.Library.Section.playing
        case .owned:
            return L10n.Library.Section.owned
        case .playtimeRecommendations:
            return L10n.Library.Section.playtimeRecommendations
        case .friendRecommendations:
            return L10n.Library.Section.friendRecommendations
        case .wishlist:
            return L10n.Library.Section.wishlist
        case .reviewed:
            return L10n.Library.Section.recentlyReviewed
        }
    }

    var subtitle: String? {
        switch self {
        case .recentlyPlayed:
            return L10n.Library.Subtitle.recentlyPlayed
        case .playtimeRecommendations:
            return L10n.Library.Subtitle.playtimeRecommendations
        case .reviewed:
            return nil
        case .playing:
            return nil
        case .owned:
            return nil
        case .friendRecommendations:
            return nil
        case .wishlist:
            return nil
        }
    }

    var systemImageName: String {
        switch self {
        case .recentlyPlayed:
            return "clock.arrow.circlepath"
        case .playing:
            return "gamecontroller.fill"
        case .owned:
            return "shippingbox.fill"
        case .playtimeRecommendations:
            return "sparkles"
        case .friendRecommendations:
            return "person.3.fill"
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
    let detailDestination: LibraryGameDetailDestination?
    let title: String
    let metadataText: String
    let ratingText: String?
    let coverImageURL: URL?
    let fallbackCoverImageURLs: [URL]
    let badgeText: String
    let actionTitle: String?
    let isActionEnabled: Bool

    init(
        identifier: LibraryGameIdentifier,
        detailDestination: LibraryGameDetailDestination?,
        title: String,
        metadataText: String,
        ratingText: String?,
        coverImageURL: URL?,
        fallbackCoverImageURLs: [URL] = [],
        badgeText: String,
        actionTitle: String?,
        isActionEnabled: Bool
    ) {
        self.identifier = identifier
        self.detailDestination = detailDestination
        self.title = title
        self.metadataText = metadataText
        self.ratingText = ratingText
        self.coverImageURL = coverImageURL
        self.fallbackCoverImageURLs = fallbackCoverImageURLs
        self.badgeText = badgeText
        self.actionTitle = actionTitle
        self.isActionEnabled = isActionEnabled
    }
}

struct LibraryGameRowViewState: Hashable {
    let identifier: LibraryGameIdentifier
    let detailDestination: LibraryGameDetailDestination?
    let title: String
    let subtitleText: String
    let metadataText: String
    let coverImageURL: URL?
    let fallbackCoverImageURLs: [URL]
    let ratingText: String?
    let trailingAction: LibraryRowTrailingAction?

    init(
        identifier: LibraryGameIdentifier,
        detailDestination: LibraryGameDetailDestination?,
        title: String,
        subtitleText: String,
        metadataText: String,
        coverImageURL: URL?,
        fallbackCoverImageURLs: [URL] = [],
        ratingText: String?,
        trailingAction: LibraryRowTrailingAction?
    ) {
        self.identifier = identifier
        self.detailDestination = detailDestination
        self.title = title
        self.subtitleText = subtitleText
        self.metadataText = metadataText
        self.coverImageURL = coverImageURL
        self.fallbackCoverImageURLs = fallbackCoverImageURLs
        self.ratingText = ratingText
        self.trailingAction = trailingAction
    }
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
    case loading
}

enum LibraryMessageAction: Hashable {
    case connectSteam
    case showSteamPrivacyGuide
    case retrySteamSync
    case retryOwnedSteamSync
    case retryPlaytimeRecommendations
    case retryFriendRecommendations
}
