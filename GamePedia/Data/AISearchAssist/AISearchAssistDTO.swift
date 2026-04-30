import Foundation

struct AISearchAssistRequestDTO: Encodable {
    let query: String
    let platforms: [String]
    let genres: [String]
    let limit: Int
}

struct AISearchAssistResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO?
    let error: AISearchAssistErrorResponseDTO?
}

struct AISearchAssistErrorResponseDTO: Decodable {
    let code: String?
    let message: String?
}

struct AISearchAssistResponseDTO: Decodable {
    let requestId: String
    let originalQuery: String?
    let normalizedQuery: String?
    let intent: AISearchAssistIntentDTO?
    let suggestedQueries: [String]?
    let items: [AISearchAssistItemDTO]
    let fallbackUsed: Bool?
    let disclaimer: String?
}

struct AISearchAssistIntentDTO: Decodable {
    let mood: [String]?
    let sessionLength: String?
    let playMode: String?
    let difficulty: String?
    let platforms: [String]?
    let genres: [String]?
    let keywords: [String]?

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

    init(
        mood: [String]? = nil,
        sessionLength: String? = nil,
        playMode: String? = nil,
        difficulty: String? = nil,
        platforms: [String]? = nil,
        genres: [String]? = nil,
        keywords: [String]? = nil
    ) {
        self.mood = mood
        self.sessionLength = sessionLength
        self.playMode = playMode
        self.difficulty = difficulty
        self.platforms = platforms
        self.genres = genres
        self.keywords = keywords
    }

    init(from decoder: Decoder) throws {
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

struct AISearchAssistItemDTO: Decodable {
    let gameId: Int
    let title: String
    let coverUrl: String?
    let platforms: [String]?
    let genres: [String]?
    let rating: Double?
    let matchReason: String?
    let matchTags: [String]?
    let rawMatchTags: [String]?
    let displayTags: [String]?
    let canonicalTags: [String]?
    let themes: [String]?
    let keywords: [String]?
    let reasonTags: [String]?
    let intentTags: [String]?
    let confidence: Double?

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
        case matchReason
        case match_reason
        case matchTags
        case match_tags
        case rawMatchTags
        case raw_match_tags
        case displayTags
        case display_tags
        case canonicalTags
        case canonical_tags
        case themes
        case keywords
        case reasonTags
        case reason_tags
        case intentTags
        case intent_tags
        case confidence
    }

    init(
        gameId: Int,
        title: String,
        coverUrl: String? = nil,
        platforms: [String]? = nil,
        genres: [String]? = nil,
        rating: Double? = nil,
        matchReason: String? = nil,
        matchTags: [String]? = nil,
        rawMatchTags: [String]? = nil,
        displayTags: [String]? = nil,
        canonicalTags: [String]? = nil,
        themes: [String]? = nil,
        keywords: [String]? = nil,
        reasonTags: [String]? = nil,
        intentTags: [String]? = nil,
        confidence: Double? = nil
    ) {
        self.gameId = gameId
        self.title = title
        self.coverUrl = coverUrl
        self.platforms = platforms
        self.genres = genres
        self.rating = rating
        self.matchReason = matchReason
        self.matchTags = matchTags
        self.rawMatchTags = rawMatchTags
        self.displayTags = displayTags
        self.canonicalTags = canonicalTags
        self.themes = themes
        self.keywords = keywords
        self.reasonTags = reasonTags
        self.intentTags = intentTags
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decodeIntIfPresent(forKeys: [.gameId, .gameID, .game_id]) ?? 0
        title = try container.decodeStringIfPresent(forKeys: [.title, .name]) ?? ""
        coverUrl = try container.decodeStringIfPresent(forKeys: [.coverUrl, .coverURL, .cover_url, .imageUrl, .imageURL, .image_url])
        platforms = try container.decodeStringArrayIfPresent(forKeys: [.platforms])
        genres = try container.decodeStringArrayIfPresent(forKeys: [.genres])
        rating = try container.decodeDoubleIfPresent(forKeys: [.rating])
        matchReason = try container.decodeStringIfPresent(forKeys: [.matchReason, .match_reason])
        matchTags = try container.decodeStringArrayIfPresent(forKeys: [.matchTags, .match_tags])
        rawMatchTags = try container.decodeStringArrayIfPresent(forKeys: [.rawMatchTags, .raw_match_tags])
        displayTags = try container.decodeStringArrayIfPresent(forKeys: [.displayTags, .display_tags])
        canonicalTags = try container.decodeStringArrayIfPresent(forKeys: [.canonicalTags, .canonical_tags])
        themes = try container.decodeStringArrayIfPresent(forKeys: [.themes])
        keywords = try container.decodeStringArrayIfPresent(forKeys: [.keywords])
        reasonTags = try container.decodeStringArrayIfPresent(forKeys: [.reasonTags, .reason_tags])
        intentTags = try container.decodeStringArrayIfPresent(forKeys: [.intentTags, .intent_tags])
        confidence = try container.decodeDoubleIfPresent(forKeys: [.confidence])
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
}
