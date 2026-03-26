import Combine
import Foundation

enum LibraryIntent {
    case viewDidLoad
    case didSelectTab(Int)
    case didSelectSort(Int)
    case didConfirmRemoveFavorite(gameId: Int)
}

final class LibraryViewModel {
    private(set) var state: LibraryState = LibraryState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((LibraryState) -> Void)?

    private let fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase
    private let removeFavoriteUseCase: RemoveFavoriteUseCase
    private var cancellables = Set<AnyCancellable>()

    init(
        fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase = FetchFavoriteGamesUseCase(
            fetchMyFavoritesUseCase: FetchMyFavoritesUseCase(
                favoriteRepository: DefaultFavoriteRepository()
            ),
            gameRepository: DefaultGameRepository()
        ),
        removeFavoriteUseCase: RemoveFavoriteUseCase = RemoveFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        )
    ) {
        self.fetchFavoriteGamesUseCase = fetchFavoriteGamesUseCase
        self.removeFavoriteUseCase = removeFavoriteUseCase
        observeFavoriteChanges()
    }

    func send(_ intent: LibraryIntent) {
        switch intent {
        case .viewDidLoad:
            loadCurrentTab()
        case .didSelectTab(let index):
            guard let tab = LibraryTab(rawValue: index), tab != state.selectedTab else { return }
            state.selectedTab = tab
            loadCurrentTab()
        case .didSelectSort(let index):
            let newSort: FavoriteSortOption = index == 1 ? .oldest : .latest
            guard newSort != state.selectedSort else { return }
            state.selectedSort = newSort
            if state.selectedTab == .favorites {
                loadFavorites()
            }
        case .didConfirmRemoveFavorite(let gameId):
            removeFavorite(gameId: gameId)
        }
    }

    private func loadCurrentTab() {
        if state.selectedTab == .favorites {
            loadFavorites()
            return
        }

        state.items = []
        state.errorMessage = nil
        state.isLoading = false
        state.favoriteCount = 0
        state.averageRatingText = "0.0"
        state.highestRatingText = "0.0"
    }

    private func loadFavorites() {
        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                let entries = try await fetchFavoriteGamesUseCase.execute(sort: state.selectedSort)
                let items = entries.map(Self.makeLibraryItem(from:))
                let favoriteCount = entries.count
                let ratings = entries.map(\.game.rating).filter { $0 > 0 }
                let averageRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)
                let highestRating = ratings.max() ?? 0

                await MainActor.run {
                    self.state.items = items
                    self.state.favoriteCount = favoriteCount
                    self.state.averageRatingText = favoriteCount > 0 ? String(format: "%.1f", averageRating) : "0.0"
                    self.state.highestRatingText = favoriteCount > 0 ? String(format: "%.1f", highestRating) : "0.0"
                    self.state.isLoading = false
                }
            } catch {
                let favoriteError = FavoriteError.from(error: error)
                await MainActor.run {
                    self.state.items = []
                    self.state.favoriteCount = 0
                    self.state.averageRatingText = "0.0"
                    self.state.highestRatingText = "0.0"
                    self.state.isLoading = false
                    self.state.errorMessage = favoriteError.errorDescription
                }
            }
        }
    }

    private func removeFavorite(gameId: Int) {
        guard state.selectedTab == .favorites, !state.isLoading else { return }

        state.isLoading = true

        Task {
            do {
                let result = try await removeFavoriteUseCase.execute(gameId: String(gameId))

                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .favoriteDidChange,
                        object: nil,
                        userInfo: [
                            FavoriteChangeUserInfoKey.gameId: result.gameId,
                            FavoriteChangeUserInfoKey.isFavorite: result.isFavorite,
                            FavoriteChangeUserInfoKey.action: FavoriteChangeAction.removed.rawValue
                        ]
                    )
                }

                await MainActor.run {
                    self.state.isLoading = false
                }

                loadFavorites()
            } catch {
                let favoriteError = FavoriteError.from(error: error)
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.errorMessage = favoriteError.errorDescription
                }
            }
        }
    }

    private func observeFavoriteChanges() {
        NotificationCenter.default.publisher(for: .favoriteDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.state.selectedTab == .favorites else { return }
                self.loadFavorites()
            }
            .store(in: &cancellables)
    }

    private static func makeLibraryItem(from entry: FavoriteGameEntry) -> LibraryGameCardItem {
        let game = entry.game
        let releaseText = game.releaseYear > 0 ? "\(game.releaseYear)" : "출시 예정"
        return LibraryGameCardItem(
            id: game.id,
            title: game.displayTitle,
            metadataText: "\(game.genre) · \(releaseText)",
            ratingValue: game.rating > 0 ? game.rating : nil,
            coverImageURL: game.coverImageURL,
            symbolName: "gamecontroller.fill",
            startColorHex: "#6E4BFF",
            endColorHex: "#1B1B21",
            isFavorite: true
        )
    }
}
