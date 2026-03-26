import Foundation

struct PostReviewRequestDTO: Encodable {
    let gameId: Int
    let rating: Double
    let body: String
    let isSpoiler: Bool
}

struct ReviewDTO: Decodable {
    let id: Int
    let userId: Int
    let userName: String
    let userAvatarUrl: String?
    let rating: Double
    let body: String
    let isSpoiler: Bool
    let createdAt: String
}

struct ReviewListResponseDTO: Decodable {
    let reviews: [ReviewDTO]
    let total: Int
}
