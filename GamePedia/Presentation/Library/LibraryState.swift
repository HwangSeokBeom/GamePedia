import Foundation

enum LibraryTab: Int {
    case playing = 0
    case favorites = 1
    case reviewed = 2

    var emptyMessage: String {
        switch self {
        case .playing:
            return "플레이중인 게임 연동은 아직 준비 중이에요."
        case .favorites:
            return "찜한 게임이 아직 없어요."
        case .reviewed:
            return "작성한 리뷰가 없어요."
        }
    }
}

enum LibrarySortOption: Int {
    case latest = 0
    case oldest = 1

    var favoriteSort: FavoriteSortOption {
        self == .oldest ? .oldest : .latest
    }

    var reviewSort: ReviewSortOption {
        self == .oldest ? .oldest : .latest
    }
}

struct LibraryState {
    var selectedTab: LibraryTab = .favorites
    var selectedSort: LibrarySortOption = .latest
    var items: [LibraryGameCardItem] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var itemCount: Int = 0
    var averageRatingText: String = "0.0"
    var highestRatingText: String = "0.0"

    var showsManagedContent: Bool {
        selectedTab != .playing
    }

    var showsEmptyState: Bool {
        !isLoading && items.isEmpty
    }

    var emptyMessage: String {
        selectedTab.emptyMessage
    }

    var countSubtitle: String {
        switch selectedTab {
        case .favorites:
            return "찜한 게임"
        case .reviewed:
            return "작성한 리뷰"
        case .playing:
            return "항목"
        }
    }
}
