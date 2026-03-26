import Foundation

// MARK: - Review

struct Review {
    let id: Int
    let authorName: String
    let authorAvatarURL: URL?
    let rating: Double
    let body: String
    let isSpoiler: Bool
    let formattedDate: String
}
