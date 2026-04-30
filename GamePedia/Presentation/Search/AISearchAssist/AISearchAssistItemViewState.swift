import Foundation

struct AISearchAssistItemViewState: Hashable {
    let gameId: Int
    let title: String
    let coverURL: URL?
    let platforms: [String]
    let genres: [String]
    let ratingText: String
    let matchReason: String
    let rawMatchTags: [String]
    let displayTags: [String]
    let confidence: Double?

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
        matchReason: String,
        matchTags: [String],
        displayTags: [String]? = nil,
        confidence: Double?
    ) {
        self.gameId = gameId
        self.title = title
        self.coverURL = coverURL
        self.platforms = platforms
        self.genres = genres
        self.ratingText = ratingText
        self.matchReason = matchReason
        self.rawMatchTags = matchTags
        self.displayTags = displayTags ?? TagLocalizer.localizedTags(
            for: matchTags,
            screen: "AISearchAssist"
        )
        self.confidence = confidence
    }

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
            return "AI 보조 결과"
        }
    }

    var visibleMatchTags: [String] {
        var seenTags = Set<String>()
        return displayTags.compactMap { tag in
            let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTag.isEmpty else { return nil }

            let normalizedTag = trimmedTag.lowercased()
            guard seenTags.insert(normalizedTag).inserted else { return nil }
            return trimmedTag
        }
        .prefix(3)
        .map { $0 }
    }

    var fitBadgeText: String? {
        guard let confidence else { return nil }
        switch confidence {
        case 0.85...:
            return "잘 맞음"
        case 0.7..<0.85:
            return "추천"
        default:
            return nil
        }
    }
}
