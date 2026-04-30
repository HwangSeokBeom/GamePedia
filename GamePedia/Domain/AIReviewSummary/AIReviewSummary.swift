import Foundation

struct AIReviewSummary: Equatable {
    let gameId: Int
    let summary: String
    let pros: [String]
    let cons: [String]
    let recommendedFor: [String]
    let notRecommendedFor: [String]
    let keywords: [String]
    let reviewCount: Int
    let sourceReviewHash: String?
    let generatedAt: Date?
    let disclaimer: String
}
