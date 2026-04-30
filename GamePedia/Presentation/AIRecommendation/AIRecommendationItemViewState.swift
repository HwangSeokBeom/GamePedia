import Foundation

struct AIRecommendationItemViewState: Hashable {
    let gameId: Int
    let title: String
    let coverURL: URL?
    let platforms: [String]
    let genres: [String]
    let ratingText: String
    let reason: String
    let rawMatchTags: [String]
    let displayTags: [String]
    let confidence: Double?
    let isPersonalized: Bool
    let isFallback: Bool
    let confidenceText: String?
    var isFavorite: Bool
    var isFavoriteUpdating: Bool

    var matchTags: [String] {
        rawMatchTags
    }

    init(
        gameId: Int,
        title: String,
        coverURL: URL?,
        platforms: [String],
        genres: [String],
        ratingText: String,
        reason: String,
        matchTags: [String],
        displayTags: [String]? = nil,
        confidence: Double?,
        isPersonalized: Bool = false,
        isFallback: Bool = false,
        confidenceText: String? = nil,
        isFavorite: Bool,
        isFavoriteUpdating: Bool
    ) {
        self.gameId = gameId
        self.title = title
        self.coverURL = coverURL
        self.platforms = platforms
        self.genres = genres
        self.ratingText = ratingText
        self.reason = reason
        self.rawMatchTags = matchTags
        self.displayTags = displayTags ?? RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: matchTags,
            genres: genres,
            maxCount: 3,
            screen: "AIRecommendation"
        )
        self.confidence = confidence
        self.isPersonalized = isPersonalized
        self.isFallback = isFallback
        self.confidenceText = confidenceText
        self.isFavorite = isFavorite
        self.isFavoriteUpdating = isFavoriteUpdating
    }

    var metadataText: String {
        let genreText = RecommendationTagLocalizer.localizedGenres(
            for: genres,
            screen: "AIRecommendation.genre"
        )
        .prefix(2)
        .joined(separator: ", ")
        let platformText = platforms.prefix(2).joined(separator: ", ")

        switch (genreText.isEmpty, platformText.isEmpty) {
        case (false, false):
            return "\(genreText) · \(platformText)"
        case (false, true):
            return genreText
        case (true, false):
            return platformText
        case (true, true):
            return L10n.Home.List.recommendation
        }
    }
}
