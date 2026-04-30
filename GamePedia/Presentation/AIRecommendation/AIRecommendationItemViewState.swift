import Foundation

struct AIRecommendationItemViewState: Hashable {
    let gameId: Int
    let title: String
    let coverURL: URL?
    let platforms: [String]
    let genres: [String]
    let ratingText: String
    let reason: String
    let matchTags: [String]
    let confidence: Double?
    var isFavorite: Bool
    var isFavoriteUpdating: Bool

    var metadataText: String {
        let genreText = genres.prefix(2).joined(separator: ", ")
        let platformText = platforms.prefix(2).joined(separator: ", ")

        switch (genreText.isEmpty, platformText.isEmpty) {
        case (false, false):
            return "\(genreText) · \(platformText)"
        case (false, true):
            return genreText
        case (true, false):
            return platformText
        case (true, true):
            return "추천 게임"
        }
    }
}
