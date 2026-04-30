import Foundation

struct AIReviewSummaryResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO?
    let error: AIReviewSummaryErrorResponseDTO?

    private enum CodingKeys: String, CodingKey {
        case success
        case data
        case error
        case gameId
        case summary
        case fallbackSummary
        case summaryText
        case content
        case text
        case status
        case reason
        case fallbackUsed
        case reviewCount
        case highlights
        case pros
        case cons
    }

    init(success: Bool, data: DataDTO?, error: AIReviewSummaryErrorResponseDTO?) {
        self.success = success
        self.data = data
        self.error = error
    }

    init(from decoder: Decoder) throws {
        if let data = try? DataDTO(from: decoder),
           Self.isSingleValuePayload(decoder) {
            self.success = true
            self.data = data
            self.error = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedData = try container.decodeIfPresent(DataDTO.self, forKey: .data)
        let topLevelData = decodedData == nil && Self.hasTopLevelPayload(in: container)
            ? try? DataDTO(from: decoder)
            : nil

        self.data = decodedData ?? topLevelData
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? (self.data != nil)
        self.error = try container.decodeIfPresent(AIReviewSummaryErrorResponseDTO.self, forKey: .error)
    }

    private static func isSingleValuePayload(_ decoder: Decoder) -> Bool {
        guard let container = try? decoder.singleValueContainer() else { return false }
        return (try? container.decode(String.self)) != nil
    }

    private static func hasTopLevelPayload(in container: KeyedDecodingContainer<CodingKeys>) -> Bool {
        [
            CodingKeys.gameId,
            .summary,
            .fallbackSummary,
            .summaryText,
            .content,
            .text,
            .status,
            .reason,
            .fallbackUsed,
            .reviewCount,
            .highlights,
            .pros,
            .cons
        ].contains { container.contains($0) }
    }
}

struct AIReviewSummaryErrorResponseDTO: Decodable {
    let code: String?
    let message: String?

    init(code: String?, message: String?) {
        self.code = code
        self.message = message
    }

    init(from decoder: Decoder) throws {
        if let message = try? decoder.singleValueContainer().decode(String.self) {
            self.code = nil
            self.message = message
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decodeIfPresent(String.self, forKey: .code)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case message
    }
}

struct AIReviewSummaryResponseDTO: Decodable {
    let gameId: Int?
    let status: String?
    let reason: String?
    let fallbackUsed: Bool?
    let summary: String?
    let highlights: [String]?
    let pros: [String]?
    let cons: [String]?
    let recommendedFor: [String]?
    let notRecommendedFor: [String]?
    let keywords: [String]?
    let reviewCount: Int?
    let sourceReviewHash: String?
    let generatedAt: String?
    let disclaimer: String?

    init(
        gameId: Int?,
        status: String?,
        reason: String?,
        fallbackUsed: Bool?,
        summary: String?,
        highlights: [String]?,
        pros: [String]?,
        cons: [String]?,
        recommendedFor: [String]?,
        notRecommendedFor: [String]?,
        keywords: [String]?,
        reviewCount: Int?,
        sourceReviewHash: String?,
        generatedAt: String?,
        disclaimer: String?
    ) {
        self.gameId = gameId
        self.status = status
        self.reason = reason
        self.fallbackUsed = fallbackUsed
        self.summary = summary
        self.highlights = highlights
        self.pros = pros
        self.cons = cons
        self.recommendedFor = recommendedFor
        self.notRecommendedFor = notRecommendedFor
        self.keywords = keywords
        self.reviewCount = reviewCount
        self.sourceReviewHash = sourceReviewHash
        self.generatedAt = generatedAt
        self.disclaimer = disclaimer
    }

    init(from decoder: Decoder) throws {
        if let summary = try? decoder.singleValueContainer().decode(String.self) {
            self.init(
                gameId: nil,
                status: nil,
                reason: nil,
                fallbackUsed: nil,
                summary: summary,
                highlights: nil,
                pros: nil,
                cons: nil,
                recommendedFor: nil,
                notRecommendedFor: nil,
                keywords: nil,
                reviewCount: nil,
                sourceReviewHash: nil,
                generatedAt: nil,
                disclaimer: nil
            )
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let summaryContent = try? container.decodeIfPresent(AIReviewSummaryContentDTO.self, forKey: .summary)
        let meta = try? container.decodeIfPresent(AIReviewSummaryMetaDTO.self, forKey: .meta)
        self.init(
            gameId: Self.decodeInt(from: container, keys: [.gameId, .id]),
            status: Self.decodeString(from: container, keys: [.status]) ?? meta?.status,
            reason: Self.decodeString(from: container, keys: [.reason]) ?? meta?.reason,
            fallbackUsed: Self.decodeBool(from: container, keys: [.fallbackUsed]) ?? meta?.fallbackUsed,
            summary: Self.decodeString(
                from: container,
                keys: [.summary, .fallbackSummary, .summaryText, .content, .text, .message]
            ) ?? summaryContent?.displaySummary,
            highlights: Self.decodeStringArray(from: container, keys: [.highlights])
                ?? summaryContent?.highlights,
            pros: Self.decodeStringArray(from: container, keys: [.pros, .strengths, .positivePoints])
                ?? summaryContent?.pros,
            cons: Self.decodeStringArray(from: container, keys: [.cons, .weaknesses, .negativePoints])
                ?? summaryContent?.cons,
            recommendedFor: Self.decodeStringArray(from: container, keys: [.recommendedFor, .recommendations])
                ?? summaryContent?.recommendedFor,
            notRecommendedFor: Self.decodeStringArray(from: container, keys: [.notRecommendedFor])
                ?? summaryContent?.notRecommendedFor,
            keywords: Self.decodeStringArray(from: container, keys: [.keywords, .tags])
                ?? summaryContent?.keywords,
            reviewCount: Self.decodeInt(from: container, keys: [.reviewCount, .reviewsCount, .totalReviews])
                ?? summaryContent?.reviewCount
                ?? meta?.reviewCount,
            sourceReviewHash: Self.decodeString(from: container, keys: [.sourceReviewHash]),
            generatedAt: Self.decodeString(from: container, keys: [.generatedAt, .createdAt, .updatedAt]),
            disclaimer: Self.decodeString(from: container, keys: [.disclaimer])
        )
    }

    private enum CodingKeys: String, CodingKey {
        case gameId
        case id
        case summary
        case fallbackSummary
        case summaryText
        case content
        case text
        case message
        case status
        case reason
        case fallbackUsed
        case highlights
        case pros
        case strengths
        case positivePoints
        case cons
        case weaknesses
        case negativePoints
        case recommendedFor
        case recommendations
        case notRecommendedFor
        case keywords
        case tags
        case reviewCount
        case reviewsCount
        case totalReviews
        case sourceReviewHash
        case generatedAt
        case createdAt
        case updatedAt
        case disclaimer
        case meta
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys where container.contains(key) {
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return String(value)
            }
        }
        return nil
    }

    private static func decodeInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for key in keys where container.contains(key) {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               let intValue = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return intValue
            }
        }
        return nil
    }

    private static func decodeBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Bool? {
        for key in keys where container.contains(key) {
            if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1", "yes":
                    return true
                case "false", "0", "no":
                    return false
                default:
                    break
                }
            }
        }
        return nil
    }

    private static func decodeStringArray(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> [String]? {
        for key in keys where container.contains(key) {
            if let values = try? container.decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return [value]
            }
        }
        return nil
    }
}

private struct AIReviewSummaryContentDTO: Decodable {
    let headline: String?
    let overview: String?
    let highlights: [String]?
    let pros: [String]?
    let cons: [String]?
    let recommendedFor: [String]?
    let notRecommendedFor: [String]?
    let keywords: [String]?
    let reviewCount: Int?

    var displaySummary: String? {
        [headline, overview]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .nilIfEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case headline
        case overview
        case highlights
        case pros
        case cons
        case recommendedFor
        case notRecommendedFor
        case keywords
        case reviewCount
    }
}

private struct AIReviewSummaryMetaDTO: Decodable {
    let status: String?
    let reason: String?
    let reviewCount: Int?
    let fallbackUsed: Bool?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
