import Foundation

struct GameDetailSeed: Hashable {
    let id: Int
    let title: String
    let genre: String?
    let developer: String?
    let releaseYear: Int?
    let coverImageURL: URL?
    let heroImageURL: URL?
    let rating: Double?
    let formattedRating: String?
    let summary: String?
    let hasSteamReview: Bool
    let sourceDescription: String

    func makePartialDetail() -> GameDetail {
        let resolvedGenre = Self.sanitized(genre) ?? L10n.Common.Label.other
        let resolvedDeveloper = Self.sanitized(developer) ?? "—"
        let resolvedReleaseYear = releaseYear ?? 0
        let detailSummary = Self.sanitized(summary) ?? L10n.Common.Label.noDescription
        let normalizedRating = rating.flatMap { value -> Double? in
            guard value.isFinite, value >= 0 else { return nil }
            return value
        } ?? 0
        let resolvedFormattedRating = formattedRating ?? "—"

        return GameDetail(
            id: id,
            title: title,
            translatedTitle: nil,
            genre: resolvedGenre,
            developer: resolvedDeveloper,
            releaseYear: resolvedReleaseYear,
            coverImageURL: coverImageURL,
            heroImageURL: heroImageURL ?? coverImageURL,
            rating: normalizedRating,
            reviewCount: 0,
            avgPlaytimeHours: 0,
            summary: detailSummary,
            translatedSummary: nil,
            storyline: detailSummary,
            translatedStoryline: nil,
            formattedRating: resolvedFormattedRating,
            formattedReviewCount: "—",
            formattedPlaytime: "—",
            developerLine: Self.makeDeveloperLine(
                developer: developer,
                genre: genre,
                releaseYear: releaseYear
            ),
            hasSteamReview: hasSteamReview
        )
    }

    func merging(with incoming: GameDetailSeed) -> GameDetailSeed {
        GameDetailSeed(
            id: id,
            title: incoming.title.isEmpty ? title : incoming.title,
            genre: Self.preferredText(current: genre, incoming: incoming.genre),
            developer: Self.preferredText(current: developer, incoming: incoming.developer),
            releaseYear: incoming.releaseYear ?? releaseYear,
            coverImageURL: incoming.coverImageURL ?? coverImageURL,
            heroImageURL: incoming.heroImageURL ?? heroImageURL ?? incoming.coverImageURL ?? coverImageURL,
            rating: incoming.rating ?? rating,
            formattedRating: incoming.formattedRating ?? formattedRating,
            summary: Self.preferredSummary(current: summary, incoming: incoming.summary),
            hasSteamReview: incoming.hasSteamReview || hasSteamReview,
            sourceDescription: incoming.sourceDescription
        )
    }

    private static func makeDeveloperLine(
        developer: String?,
        genre: String?,
        releaseYear: Int?
    ) -> String {
        let parts = [
            sanitized(developer),
            sanitized(genre),
            releaseYear.flatMap { $0 > 0 ? String($0) : nil }
        ].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private static func preferredText(current: String?, incoming: String?) -> String? {
        sanitized(incoming) ?? sanitized(current)
    }

    private static func preferredSummary(current: String?, incoming: String?) -> String? {
        let currentSummary = meaningfulSummary(current)
        let incomingSummary = meaningfulSummary(incoming)

        if let incomingSummary, let currentSummary {
            return incomingSummary.count >= currentSummary.count ? incomingSummary : currentSummary
        }

        return incomingSummary ?? currentSummary
    }

    private static func meaningfulSummary(_ value: String?) -> String? {
        guard let sanitizedValue = sanitized(value) else { return nil }
        return sanitizedValue == L10n.Common.Label.noDescription ? nil : sanitizedValue
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, trimmedValue != "—" else { return nil }
        return trimmedValue
    }
}

final class GameDetailSeedStore {
    static let shared = GameDetailSeedStore()

    private let lock = NSLock()
    private var seedsByGameID: [Int: GameDetailSeed] = [:]

    private init() {}

    func seed(for gameID: Int) -> GameDetailSeed? {
        lock.lock()
        defer { lock.unlock() }
        return seedsByGameID[gameID]
    }

    func store(_ seed: GameDetailSeed) {
        guard seed.id > 0 else { return }

        lock.lock()
        defer { lock.unlock() }

        if let current = seedsByGameID[seed.id] {
            seedsByGameID[seed.id] = current.merging(with: seed)
        } else {
            seedsByGameID[seed.id] = seed
        }
    }

    func store(games: [Game], screen: String) {
        games.forEach { game in
            store(
                GameDetailSeed(
                    id: game.id,
                    title: game.title,
                    genre: game.genre,
                    developer: game.developer,
                    releaseYear: game.releaseYear > 0 ? game.releaseYear : nil,
                    coverImageURL: game.coverImageURL,
                    heroImageURL: game.coverImageURL,
                    rating: game.rating.isFinite && game.rating >= 0 ? game.rating : nil,
                    formattedRating: game.formattedRating == "—" ? nil : game.formattedRating,
                    summary: game.summary,
                    hasSteamReview: false,
                    sourceDescription: screen
                )
            )
        }
    }

    func store(librarySummaries: [LibraryGameSummary], screen: String) {
        librarySummaries.forEach { summary in
            store(
                GameDetailSeed(
                    id: summary.igdbGameId ?? 0,
                    title: summary.title,
                    genre: summary.displayableGenreText,
                    developer: nil,
                    releaseYear: summary.releaseYear > 0 ? summary.releaseYear : nil,
                    coverImageURL: summary.coverImageURL,
                    heroImageURL: summary.coverImageURL,
                    rating: summary.rating,
                    formattedRating: summary.formattedRatingText,
                    summary: nil,
                    hasSteamReview: false,
                    sourceDescription: screen
                )
            )
        }
    }

    func store(recentGames: [RecentGame], screen: String) {
        recentGames.forEach { game in
            store(
                GameDetailSeed(
                    id: game.resolvedDetailGameId ?? 0,
                    title: game.title,
                    genre: nil,
                    developer: nil,
                    releaseYear: nil,
                    coverImageURL: game.coverImageURL,
                    heroImageURL: game.coverImageURL,
                    rating: game.userRating,
                    formattedRating: game.formattedRating,
                    summary: nil,
                    hasSteamReview: false,
                    sourceDescription: screen
                )
            )
        }
    }

    func store(items: [LibraryCollectionItem], screen: String) {
        items.forEach { item in
            switch item {
            case .recentCard(let viewState):
                if case .igdb(let gameID) = viewState.detailDestination {
                    store(
                        GameDetailSeed(
                            id: gameID,
                            title: viewState.title,
                            genre: nil,
                            developer: nil,
                            releaseYear: nil,
                            coverImageURL: viewState.coverImageURL,
                            heroImageURL: viewState.coverImageURL,
                            rating: nil,
                            formattedRating: viewState.ratingText,
                            summary: nil,
                            hasSteamReview: false,
                            sourceDescription: screen
                        )
                    )
                }
            case .row(let viewState):
                if case .igdb(let gameID) = viewState.detailDestination {
                    store(
                        GameDetailSeed(
                            id: gameID,
                            title: viewState.title,
                            genre: nil,
                            developer: nil,
                            releaseYear: nil,
                            coverImageURL: viewState.coverImageURL,
                            heroImageURL: viewState.coverImageURL,
                            rating: nil,
                            formattedRating: viewState.ratingText,
                            summary: nil,
                            hasSteamReview: false,
                            sourceDescription: screen
                        )
                    )
                }
            case .message:
                break
            }
        }
    }
}
