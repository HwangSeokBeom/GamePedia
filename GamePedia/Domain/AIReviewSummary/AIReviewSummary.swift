import Foundation

struct AIReviewSummary: Equatable {
    let gameId: Int
    let status: String
    let reason: String?
    let fallbackUsed: Bool
    let highlights: [String]
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
