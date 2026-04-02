import Combine
import Foundation

enum LibraryIntent {
    case viewDidLoad
    case didSelectTab(Int)
    case didSelectSort(Int)
    case didConfirmRemoveFavorite(gameId: Int)
}

final class LibraryViewModel {
    private(set) var state: LibraryState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((LibraryState) -> Void)?

    private let fetchFavoriteGamesUseCase: FetchFavoriteGamesUseCase
    private let fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase
    private let removeFavoriteUseCase: RemoveFavoriteUseCase
    private let translateTextUseCase: TranslateTextUseCase
    private var cancellables = Set<AnyCancellable>()

    init(
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
        initialTab: LibraryTab = .favorites,
        removeFavoriteUseCase: RemoveFavoriteUseCase = RemoveFavoriteUseCase(
            favoriteRepository: DefaultFavoriteRepository()
        ),
        translateTextUseCase: TranslateTextUseCase = DefaultTranslateTextUseCase(
            repository: DefaultTranslationRepository(),
            languageProvider: DefaultLanguageProvider.shared
        )
    ) {
        self.state = LibraryState(selectedTab: initialTab)
        self.fetchFavoriteGamesUseCase = fetchFavoriteGamesUseCase
        self.fetchMyReviewedGamesUseCase = fetchMyReviewedGamesUseCase
        self.removeFavoriteUseCase = removeFavoriteUseCase
        self.translateTextUseCase = translateTextUseCase
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
            let newSort: LibrarySortOption = index == 1 ? .oldest : .latest
            guard newSort != state.selectedSort else { return }
            state.selectedSort = newSort
            loadCurrentTab()
        case .didConfirmRemoveFavorite(let gameId):
            removeFavorite(gameId: gameId)
        }
    }

    private func loadCurrentTab() {
        if state.selectedTab == .favorites {
            loadFavorites()
            return
        }

        if state.selectedTab == .reviewed {
            loadReviewedGames()
            return
        }

        state.items = []
        state.errorMessage = nil
        state.isLoading = false
        state.itemCount = 0
        state.averageRatingText = "0.0"
        state.highestRatingText = "0.0"
    }

    private func loadFavorites() {
        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                let entries = try await fetchFavoriteGamesUseCase.execute(sort: state.selectedSort.favoriteSort)
                print("[LibraryTranslation] favorites translation start count=\(entries.count)")
                let translatedEntries = await translateFavoriteEntries(entries)
                let items = translatedEntries.map(Self.makeLibraryItem(from:))
                let favoriteCount = entries.count
                let ratings = translatedEntries.map(\.game.rating).filter { $0 > 0 }
                let averageRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)
                let highestRating = ratings.max() ?? 0
                print("[LibraryTranslation] favorites translation complete itemCount=\(items.count)")

                await MainActor.run {
                    self.state.items = items
                    self.state.itemCount = favoriteCount
                    self.state.averageRatingText = favoriteCount > 0 ? String(format: "%.1f", averageRating) : "0.0"
                    self.state.highestRatingText = favoriteCount > 0 ? String(format: "%.1f", highestRating) : "0.0"
                    self.state.isLoading = false
                }
            } catch {
                let favoriteError = FavoriteError.from(error: error)
                await MainActor.run {
                    self.state.items = []
                    self.state.itemCount = 0
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

        NotificationCenter.default.publisher(for: .reviewDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.state.selectedTab == .reviewed else { return }
                self.loadReviewedGames()
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
            isFavorite: true,
            showsFavoriteButton: true
        )
    }

    private func loadReviewedGames() {
        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                let reviewedGames = try await fetchMyReviewedGamesUseCase.execute(sort: state.selectedSort.reviewSort)
                print("[LibraryTranslation] reviewed translation start count=\(reviewedGames.count)")
                let translatedReviewedGames = await translateReviewedGames(reviewedGames)
                let items = translatedReviewedGames.map(Self.makeLibraryItem(from:))
                let reviewCount = reviewedGames.count
                let ratings = translatedReviewedGames.map(\.rating).filter { $0 > 0 }
                let averageRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)
                let highestRating = ratings.max() ?? 0
                print("[LibraryTranslation] reviewed translation complete itemCount=\(items.count)")

                await MainActor.run {
                    self.state.items = items
                    self.state.itemCount = reviewCount
                    self.state.averageRatingText = reviewCount > 0 ? String(format: "%.1f", averageRating) : "0.0"
                    self.state.highestRatingText = reviewCount > 0 ? String(format: "%.1f", highestRating) : "0.0"
                    self.state.isLoading = false
                }
            } catch {
                let reviewError = ReviewError.from(error: error)
                await MainActor.run {
                    self.state.items = []
                    self.state.itemCount = 0
                    self.state.averageRatingText = "0.0"
                    self.state.highestRatingText = "0.0"
                    self.state.isLoading = false
                    self.state.errorMessage = reviewError.errorDescription
                }
            }
        }
    }

    private static func makeLibraryItem(from reviewedGame: ReviewedGame) -> LibraryGameCardItem {
        LibraryGameCardItem(
            id: reviewedGame.gameId,
            title: reviewedGame.game.displayTitle,
            metadataText: reviewedGame.contentPreview,
            ratingValue: reviewedGame.rating,
            coverImageURL: reviewedGame.game.coverImageURL,
            symbolName: "text.bubble.fill",
            startColorHex: "#FF8A65",
            endColorHex: "#1B1B21",
            isFavorite: false,
            showsFavoriteButton: false
        )
    }

    private func translateFavoriteEntries(_ entries: [FavoriteGameEntry]) async -> [FavoriteGameEntry] {
        let translatedGames = await translateGames(entries.map(\.game), context: "Library.favorites")
        let translatedGamesByID = Dictionary(uniqueKeysWithValues: translatedGames.map { ($0.id, $0) })

        return entries.map { entry in
            FavoriteGameEntry(
                favorite: entry.favorite,
                game: translatedGamesByID[entry.game.id] ?? entry.game
            )
        }
    }

    private func translateReviewedGames(_ reviewedGames: [ReviewedGame]) async -> [ReviewedGame] {
        let translatedGames = await translateGames(reviewedGames.map(\.game), context: "Library.reviewed")
        let translatedGamesByID = Dictionary(uniqueKeysWithValues: translatedGames.map { ($0.id, $0) })

        return reviewedGames.map { reviewedGame in
            ReviewedGame(
                reviewId: reviewedGame.reviewId,
                gameId: reviewedGame.gameId,
                rating: reviewedGame.rating,
                content: reviewedGame.content,
                createdAt: reviewedGame.createdAt,
                game: translatedGamesByID[reviewedGame.game.id] ?? reviewedGame.game
            )
        }
    }

    private func translateGames(_ games: [Game], context: String) async -> [Game] {
        guard !games.isEmpty else { return games }

        let titleItems = games.compactMap { game -> TranslationRequestItem? in
            guard game.translatedTitle == nil else { return nil }
            return TranslationRequestItem(
                identifier: String(game.id),
                field: "title",
                text: game.title
            )
        }

        guard !titleItems.isEmpty else { return games }

        let translatedTitles = Dictionary(
            uniqueKeysWithValues: await translateTextUseCase.execute(
                items: titleItems,
                context: "\(context).title",
                sourceLanguage: "en"
            ).map { ($0.identifier, $0.translatedText) }
        )

        return games.map { game in
            game.replacingTranslated(
                translatedTitle: translatedTitles[String(game.id)]
            )
        }
    }
}
