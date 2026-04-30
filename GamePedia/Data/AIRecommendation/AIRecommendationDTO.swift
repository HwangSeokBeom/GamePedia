import Foundation

struct AIRecommendationRequestDTO: Encodable {
    let query: String
    let platforms: [String]?
    let preferredGenres: [String]?
    let excludedGameIds: [String]?
    let limit: Int?
    let personalization: Bool
    let includeOwned: Bool?
    let includeReviewed: Bool?
    let includeFavorites: Bool?

    init(
        query: String,
        platforms: [String]? = nil,
        preferredGenres: [String]? = nil,
        excludedGameIds: [String]? = nil,
        limit: Int? = 10,
        personalization: Bool = true,
        includeOwned: Bool? = false,
        includeReviewed: Bool? = false,
        includeFavorites: Bool? = false
    ) {
        self.query = query
        self.platforms = platforms
        self.preferredGenres = preferredGenres
        self.excludedGameIds = excludedGameIds
        self.limit = limit
        self.personalization = personalization
        self.includeOwned = includeOwned
        self.includeReviewed = includeReviewed
        self.includeFavorites = includeFavorites
    }
}

struct AIRecommendationResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO?
    let error: AIRecommendationErrorResponseDTO?
}

struct AIRecommendationErrorResponseDTO: Decodable {
    let code: String?
    let message: String?
}

struct AIRecommendationResponseDTO: Decodable {
    let requestId: String?
    let normalizedQuery: String?
    let intent: AIRecommendationIntentDTO?
    let items: [AIRecommendationItemDTO]
    let meta: AIRecommendationMetaDTO?
    let disclaimer: String?

    enum CodingKeys: String, CodingKey {
        case requestId
        case requestID
        case request_id
        case normalizedQuery
        case normalized_query
        case intent
        case items
        case meta
        case disclaimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try container.decodeStringIfPresent(forKeys: [.requestId, .requestID, .request_id])
        normalizedQuery = try container.decodeStringIfPresent(forKeys: [.normalizedQuery, .normalized_query])
        intent = try? container.decodeIfPresent(AIRecommendationIntentDTO.self, forKey: .intent)
        items = (try? container.decodeIfPresent([AIRecommendationItemDTO].self, forKey: .items)) ?? []
        meta = try? container.decodeIfPresent(AIRecommendationMetaDTO.self, forKey: .meta)
        disclaimer = try container.decodeStringIfPresent(forKeys: [.disclaimer])
    }
}

struct AIRecommendationIntentDTO: Decodable {
    let mood: [String]?
    let sessionLength: String?
    let playMode: String?
    let difficulty: String?
    let platforms: [String]?
    let genres: [String]?
    let keywords: [String]?
    let raw: [String: AIRecommendationJSONValue]

    enum CodingKeys: String, CodingKey {
        case mood
        case sessionLength
        case session_length
        case playMode
        case play_mode
        case difficulty
        case platforms
        case genres
        case keywords
    }

    init(from decoder: Decoder) throws {
        raw = (try? decoder.singleValueContainer().decode([String: AIRecommendationJSONValue].self)) ?? [:]
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mood = try container.decodeStringArrayIfPresent(forKeys: [.mood])
        sessionLength = try container.decodeStringIfPresent(forKeys: [.sessionLength, .session_length])
        playMode = try container.decodeStringIfPresent(forKeys: [.playMode, .play_mode])
        difficulty = try container.decodeStringIfPresent(forKeys: [.difficulty])
        platforms = try container.decodeStringArrayIfPresent(forKeys: [.platforms])
        genres = try container.decodeStringArrayIfPresent(forKeys: [.genres])
        keywords = try container.decodeStringArrayIfPresent(forKeys: [.keywords])
    }
}

struct AIRecommendationItemDTO: Decodable {
    let gameId: String
    let title: String?
    let coverUrl: String?
    let imageUrl: String?
    let platforms: [String]?
    let genres: [String]?
    let rating: Double?
    let reason: String?
    let matchTags: [String]?
    let rawMatchTags: [String]?
    let displayTags: [String]?
    let canonicalTags: [String]?
    let genresTags: [String]?
    let themes: [String]?
    let keywords: [String]?
    let reasonTags: [String]?
    let intentTags: [String]?
    let confidence: Double?
    let recommendationSource: String?
    let personalized: Bool?
    let fallbackUsed: Bool?

    enum CodingKeys: String, CodingKey {
        case gameId
        case gameID
        case game_id
        case title
        case name
        case coverUrl
        case coverURL
        case cover_url
        case imageUrl
        case imageURL
        case image_url
        case platforms
        case genres
        case rating
        case reason
        case matchTags
        case match_tags
        case rawMatchTags
        case raw_match_tags
        case displayTags
        case display_tags
        case canonicalTags
        case canonical_tags
        case genreTags
        case genre_tags
        case themes
        case keywords
        case reasonTags
        case reason_tags
        case intentTags
        case intent_tags
        case confidence
        case recommendationSource
        case recommendation_source
        case source
        case personalized
        case fallbackUsed
        case fallback_used
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decodeStringIfPresent(forKeys: [.gameId, .gameID, .game_id]) ?? ""
        title = try container.decodeStringIfPresent(forKeys: [.title, .name])
        coverUrl = try container.decodeStringIfPresent(forKeys: [.coverUrl, .coverURL, .cover_url])
        imageUrl = try container.decodeStringIfPresent(forKeys: [.imageUrl, .imageURL, .image_url])
        platforms = try container.decodeStringArrayIfPresent(forKeys: [.platforms])
        genres = try container.decodeStringArrayIfPresent(forKeys: [.genres])
        rating = try container.decodeDoubleIfPresent(forKeys: [.rating])
        reason = try container.decodeStringIfPresent(forKeys: [.reason])
        matchTags = try container.decodeStringArrayIfPresent(forKeys: [.matchTags, .match_tags])
        rawMatchTags = try container.decodeStringArrayIfPresent(forKeys: [.rawMatchTags, .raw_match_tags])
        displayTags = try container.decodeStringArrayIfPresent(forKeys: [.displayTags, .display_tags])
        canonicalTags = try container.decodeStringArrayIfPresent(forKeys: [.canonicalTags, .canonical_tags])
        genresTags = try container.decodeStringArrayIfPresent(forKeys: [.genreTags, .genre_tags])
        themes = try container.decodeStringArrayIfPresent(forKeys: [.themes])
        keywords = try container.decodeStringArrayIfPresent(forKeys: [.keywords])
        reasonTags = try container.decodeStringArrayIfPresent(forKeys: [.reasonTags, .reason_tags])
        intentTags = try container.decodeStringArrayIfPresent(forKeys: [.intentTags, .intent_tags])
        confidence = try container.decodeDoubleIfPresent(forKeys: [.confidence])
        recommendationSource = try container.decodeStringIfPresent(
            forKeys: [.recommendationSource, .recommendation_source, .source]
        )
        personalized = try container.decodeBoolIfPresent(forKeys: [.personalized])
        fallbackUsed = try container.decodeBoolIfPresent(forKeys: [.fallbackUsed, .fallback_used])
    }
}

struct AIRecommendationMetaDTO: Decodable {
    let personalizationUsed: Bool?
    let personalizationAvailable: Bool?
    let fallbackUsed: Bool?
    let source: String?
    let candidateCount: Int?
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case personalizationUsed
        case personalization_used
        case personalizationAvailable
        case personalization_available
        case fallbackUsed
        case fallback_used
        case source
        case candidateCount
        case candidate_count
        case generatedAt
        case generated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        personalizationUsed = try container.decodeBoolIfPresent(
            forKeys: [.personalizationUsed, .personalization_used]
        )
        personalizationAvailable = try container.decodeBoolIfPresent(
            forKeys: [.personalizationAvailable, .personalization_available]
        )
        fallbackUsed = try container.decodeBoolIfPresent(forKeys: [.fallbackUsed, .fallback_used])
        source = try container.decodeStringIfPresent(forKeys: [.source])
        candidateCount = try container.decodeIntIfPresent(forKeys: [.candidateCount, .candidate_count])
        generatedAt = try container.decodeStringIfPresent(forKeys: [.generatedAt, .generated_at])
    }
}

enum AIRecommendationJSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: AIRecommendationJSONValue])
    case array([AIRecommendationJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AIRecommendationJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AIRecommendationJSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeStringIfPresent(forKeys keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return String(value)
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return String(value)
            }
        }
        return nil
    }

    func decodeStringArrayIfPresent(forKeys keys: [Key]) throws -> [String]? {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let values = try? decodeIfPresent([Int].self, forKey: key) {
                return values.map(String.init)
            }
        }
        return nil
    }

    func decodeDoubleIfPresent(forKeys keys: [Key]) throws -> Double? {
        for key in keys {
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let doubleValue = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return doubleValue
            }
        }
        return nil
    }

    func decodeIntIfPresent(forKeys keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let intValue = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return intValue
            }
        }
        return nil
    }

    func decodeBoolIfPresent(forKeys keys: [Key]) throws -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "1", "yes"].contains(normalizedValue) { return true }
                if ["false", "0", "no"].contains(normalizedValue) { return false }
            }
        }
        return nil
    }
}
