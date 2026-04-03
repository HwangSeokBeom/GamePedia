import XCTest
@testable import GamePedia

final class HomeHighlightSelectorTests: XCTestCase {

    func testSelectHighlights_prefersRichMetadataAndLimitsToFive() {
        let selector = DefaultHomeHighlightSelector()

        let candidates = [
            makeGame(id: 1, title: "Elden Ring", genre: "RPG", rating: 4.8, popularity: 95, isTrending: true),
            makeGame(id: 2, title: "Hades II", genre: "Roguelike", rating: 4.7, popularity: 88),
            makeGame(id: 3, title: "Astro Bot", genre: "Platformer", rating: 4.6, popularity: 82),
            makeGame(id: 4, title: "Metaphor", genre: "RPG", rating: 4.5, popularity: 79),
            makeGame(id: 5, title: "Balatro", genre: "Card", rating: 4.9, popularity: 91),
            makeGame(id: 6, title: "Clair Obscur", genre: "RPG", rating: 4.4, popularity: 77)
        ]

        let highlights = selector.selectHighlights(from: candidates, minimumCount: 3, maximumCount: 5)

        XCTAssertEqual(highlights.count, 5)
        XCTAssertEqual(highlights.first?.game.id, 1)
        XCTAssertEqual(highlights.first?.badgeText, "오늘의 추천")
    }

    func testSelectHighlights_excludesMissingCoverAndWeakMetadataCandidates() {
        let selector = DefaultHomeHighlightSelector()

        let valid = makeGame(id: 10, title: "Tekken 8", genre: "Fighting", rating: 4.2, popularity: 73)
        let missingCover = makeGame(id: 11, title: "No Cover", genre: "Action", rating: 4.8, popularity: 90, coverImageURL: nil)
        let longTitle = makeGame(
            id: 12,
            title: "This Title Is Definitely Way Too Long For The Highlight Slot",
            genre: "Action",
            rating: 4.7,
            popularity: 88
        )
        let weakMetadata = makeGame(
            id: 13,
            title: "Sparse",
            genre: "",
            rating: 4.0,
            popularity: 55,
            summary: nil,
            releaseDate: nil
        )

        let highlights = selector.selectHighlights(
            from: [valid, missingCover, longTitle, weakMetadata],
            minimumCount: 1,
            maximumCount: 5
        )

        XCTAssertEqual(highlights.map(\.game.id), [10])
    }

    private func makeGame(
        id: Int,
        title: String,
        genre: String,
        rating: Double,
        popularity: Double,
        summary: String? = "첫 화면 카드에 보여줄 만한 설명이 충분한 작품입니다.",
        releaseDate: Date? = Date(timeIntervalSince1970: 1_710_000_000),
        coverImageURL: URL? = URL(string: "https://example.com/highlight-\(UUID().uuidString).jpg"),
        isTrending: Bool = false
    ) -> Game {
        let releaseYear = releaseDate.map { Calendar.current.component(.year, from: $0) } ?? 0
        return Game(
            id: id,
            title: title,
            translatedTitle: nil,
            summary: summary,
            translatedSummary: nil,
            genre: genre,
            category: genre,
            developer: "Studio",
            platform: "PS5",
            releaseDate: releaseDate,
            releaseYear: releaseYear,
            coverImageURL: coverImageURL,
            rating: rating,
            reviewCount: Int(popularity),
            popularity: popularity,
            isTrending: isTrending,
            formattedRating: String(format: "%.1f", rating),
            formattedReviewCount: "\(Int(popularity))"
        )
    }
}
