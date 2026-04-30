import Foundation

struct AIReviewSummaryResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO?
    let error: AIReviewSummaryErrorResponseDTO?
}

struct AIReviewSummaryErrorResponseDTO: Decodable {
    let code: String?
    let message: String?
}

struct AIReviewSummaryResponseDTO: Decodable {
    let gameId: Int
    let summary: String?
    let pros: [String]?
    let cons: [String]?
    let recommendedFor: [String]?
    let notRecommendedFor: [String]?
    let keywords: [String]?
    let reviewCount: Int?
    let sourceReviewHash: String?
    let generatedAt: String?
    let disclaimer: String?
}
