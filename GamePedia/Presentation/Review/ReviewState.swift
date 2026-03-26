import Foundation

// MARK: - ReviewState

struct ReviewState {
    let gameId: Int
    let gameName: String
    let gameSubtitle: String
    let gameThumbnailURL: String
    let maxChars: Int

    var rating: Float
    var reviewText: String
    var charCount: Int
    var isSpoiler: Bool
    var isSubmitting: Bool
    var submitEnabled: Bool
    var didSubmitSuccessfully: Bool
    var errorMessage: String?

    init(
        gameId: Int,
        gameName: String,
        gameSubtitle: String = "",
        gameThumbnailURL: String,
        maxChars: Int = 500
    ) {
        self.gameId = gameId
        self.gameName = gameName
        self.gameSubtitle = gameSubtitle
        self.gameThumbnailURL = gameThumbnailURL
        self.maxChars = maxChars
        self.rating = 0
        self.reviewText = ""
        self.charCount = 0
        self.isSpoiler = false
        self.isSubmitting = false
        self.submitEnabled = false
        self.didSubmitSuccessfully = false
        self.errorMessage = nil
    }

    var formattedRating: String {
        String(format: "%.1f / 5.0", rating)
    }

    var formattedCharCount: String {
        "\(charCount) / \(maxChars)자"
    }
}
