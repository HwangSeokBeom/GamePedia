import Foundation

struct CreateReviewRequestDTO: Encodable {
    let gameId: String
    let rating: Double
    let content: String
}

struct UpdateReviewRequestDTO: Encodable {
    let rating: Double?
    let content: String?
}

struct ReviewResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct ReviewAuthorDTO: Decodable {
    let id: String
    let nickname: String
    let profileImageUrl: String?
}

struct ReviewDTO: Decodable {
    let id: String
    let gameId: String
    let rating: Double
    let content: String
    let createdAt: String
    let updatedAt: String
    let author: ReviewAuthorDTO
    let isMine: Bool
}

struct ReviewSummaryDTO: Decodable {
    let reviewCount: Int
    let averageRating: Double?
}

struct ReviewObjectResponseDataDTO: Decodable {
    let review: ReviewDTO
}

struct ReviewListResponseDataDTO: Decodable {
    let reviews: [ReviewDTO]
    let meta: ReviewSummaryDTO
}

struct MyReviewsResponseDataDTO: Decodable {
    let reviews: [ReviewDTO]
}

struct DeleteReviewResponseDataDTO: Decodable {
    let deleted: Bool
    let reviewId: String
}
