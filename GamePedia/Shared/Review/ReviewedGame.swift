import Foundation

struct ReviewedGame: Hashable {
    let reviewId: String
    let gameId: Int
    let rating: Double
    let content: String
    let createdAt: String
    let game: Game

    var contentPreview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 52 else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 52)
        return "\(trimmed[..<index])..."
    }
}
