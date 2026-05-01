import Foundation

struct LibraryCuratorRequestDTO: Encodable {
    let query: String?
    let mode: String
    let limit: Int
    let locale: String
    let candidateScope: String
    let excludedGameIds: [String]
}

struct LibraryCuratorResponseEnvelopeDTO: Decodable {
    let success: Bool
    let data: LibraryCuratorResponseDataDTO?
    let error: LibraryCuratorErrorResponseDTO?
}

struct LibraryCuratorErrorResponseDTO: Decodable {
    let code: String?
    let message: String?
}

struct LibraryCuratorResponseDataDTO: Decodable {
    let mode: String
    let source: String
    let summary: LibraryCuratorSummaryDTO
    let tasteProfile: LibraryCuratorTasteProfileDTO
    let sections: [LibraryCuratorSectionDTO]
    let games: [LibraryCuratorGameDTO]
    let meta: LibraryCuratorMetaDTO
}

struct LibraryCuratorSummaryDTO: Decodable {
    let title: String
    let body: String
    let bullets: [String]
}

struct LibraryCuratorTasteProfileDTO: Decodable {
    let topGenres: [String]
    let topThemes: [String]
    let preferredSession: String
    let playStyleTags: [String]
    let ratingStyle: String?
}

struct LibraryCuratorSectionDTO: Decodable {
    let id: String
    let title: String
    let description: String
    let items: [LibraryCuratorItemDTO]
}

struct LibraryCuratorItemDTO: Decodable {
    let gameId: String
    let reason: String
    let matchTags: [String]
    let confidence: Double
}

struct LibraryCuratorGameDTO: Decodable {
    let gameId: String
    let title: String
    let coverUrl: String?
    let genres: [String]
    let platforms: [String]
    let rating: Double?
    let source: String?
    let playtimeMinutes: Int?
    let lastPlayedAt: String?
    let isFavorite: Bool
    let hasReview: Bool
    let userRating: Double?
}

struct LibraryCuratorMetaDTO: Decodable {
    let candidateCount: Int
    let selectedCount: Int
    let fallbackReason: String?
    let generatedAt: String
    let locale: String
}

extension LibraryCuratorResponseDataDTO {
    enum CodingKeys: String, CodingKey {
        case mode
        case source
        case summary
        case tasteProfile
        case taste_profile
        case sections
        case games
        case meta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeStringIfPresent(forKeys: [.mode]) ?? LibraryCuratorMode.overview.rawValue
        source = try container.decodeStringIfPresent(forKeys: [.source]) ?? "fallback"
        summary = (try? container.decodeIfPresent(LibraryCuratorSummaryDTO.self, forKey: .summary))
            ?? LibraryCuratorSummaryDTO(title: "", body: "", bullets: [])
        tasteProfile = (try? container.decodeIfPresent(LibraryCuratorTasteProfileDTO.self, forKey: .tasteProfile))
            ?? (try? container.decodeIfPresent(LibraryCuratorTasteProfileDTO.self, forKey: .taste_profile))
            ?? LibraryCuratorTasteProfileDTO(
                topGenres: [],
                topThemes: [],
                preferredSession: "",
                playStyleTags: [],
                ratingStyle: nil
            )
        sections = (try? container.decodeIfPresent([LibraryCuratorSectionDTO].self, forKey: .sections)) ?? []
        games = (try? container.decodeIfPresent([LibraryCuratorGameDTO].self, forKey: .games)) ?? []
        meta = (try? container.decodeIfPresent(LibraryCuratorMetaDTO.self, forKey: .meta))
            ?? LibraryCuratorMetaDTO(
                candidateCount: 0,
                selectedCount: 0,
                fallbackReason: nil,
                generatedAt: "",
                locale: DefaultLanguageProvider.shared.currentLanguageCode
            )
    }
}

extension LibraryCuratorSummaryDTO {
    enum CodingKeys: String, CodingKey {
        case title
        case body
        case bullets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeStringIfPresent(forKeys: [.title]) ?? ""
        body = try container.decodeStringIfPresent(forKeys: [.body]) ?? ""
        bullets = (try? container.decodeStringArrayIfPresent(forKeys: [.bullets])) ?? []
    }
}

extension LibraryCuratorTasteProfileDTO {
    enum CodingKeys: String, CodingKey {
        case topGenres
        case top_genres
        case topThemes
        case top_themes
        case preferredSession
        case preferred_session
        case playStyleTags
        case play_style_tags
        case ratingStyle
        case rating_style
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topGenres = (try? container.decodeStringArrayIfPresent(forKeys: [.topGenres, .top_genres])) ?? []
        topThemes = (try? container.decodeStringArrayIfPresent(forKeys: [.topThemes, .top_themes])) ?? []
        preferredSession = try container.decodeStringIfPresent(forKeys: [.preferredSession, .preferred_session]) ?? ""
        playStyleTags = (try? container.decodeStringArrayIfPresent(forKeys: [.playStyleTags, .play_style_tags])) ?? []
        ratingStyle = try container.decodeStringIfPresent(forKeys: [.ratingStyle, .rating_style])
    }
}

extension LibraryCuratorSectionDTO {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeStringIfPresent(forKeys: [.id]) ?? UUID().uuidString
        title = try container.decodeStringIfPresent(forKeys: [.title]) ?? ""
        description = try container.decodeStringIfPresent(forKeys: [.description]) ?? ""
        items = (try? container.decodeIfPresent([LibraryCuratorItemDTO].self, forKey: .items)) ?? []
    }
}

extension LibraryCuratorItemDTO {
    enum CodingKeys: String, CodingKey {
        case gameId
        case gameID
        case game_id
        case reason
        case matchTags
        case match_tags
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decodeStringIfPresent(forKeys: [.gameId, .gameID, .game_id]) ?? ""
        reason = try container.decodeStringIfPresent(forKeys: [.reason]) ?? ""
        matchTags = (try? container.decodeStringArrayIfPresent(forKeys: [.matchTags, .match_tags])) ?? []
        confidence = try container.decodeDoubleIfPresent(forKeys: [.confidence]) ?? 0
    }
}

extension LibraryCuratorGameDTO {
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
        case genres
        case platforms
        case rating
        case source
        case playtimeMinutes
        case playtime_minutes
        case lastPlayedAt
        case last_played_at
        case isFavorite
        case is_favorite
        case hasReview
        case has_review
        case userRating
        case user_rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameId = try container.decodeStringIfPresent(forKeys: [.gameId, .gameID, .game_id]) ?? ""
        title = try container.decodeStringIfPresent(forKeys: [.title, .name]) ?? ""
        coverUrl = try container.decodeStringIfPresent(forKeys: [.coverUrl, .coverURL, .cover_url, .imageUrl, .imageURL, .image_url])
        genres = (try? container.decodeStringArrayIfPresent(forKeys: [.genres])) ?? []
        platforms = (try? container.decodeStringArrayIfPresent(forKeys: [.platforms])) ?? []
        rating = try container.decodeDoubleIfPresent(forKeys: [.rating])
        source = try container.decodeStringIfPresent(forKeys: [.source])
        playtimeMinutes = try container.decodeIntIfPresent(forKeys: [.playtimeMinutes, .playtime_minutes])
        lastPlayedAt = try container.decodeStringIfPresent(forKeys: [.lastPlayedAt, .last_played_at])
        isFavorite = try container.decodeBoolIfPresent(forKeys: [.isFavorite, .is_favorite]) ?? false
        hasReview = try container.decodeBoolIfPresent(forKeys: [.hasReview, .has_review]) ?? false
        userRating = try container.decodeDoubleIfPresent(forKeys: [.userRating, .user_rating])
    }
}

extension LibraryCuratorMetaDTO {
    enum CodingKeys: String, CodingKey {
        case candidateCount
        case candidate_count
        case selectedCount
        case selected_count
        case fallbackReason
        case fallback_reason
        case generatedAt
        case generated_at
        case locale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        candidateCount = try container.decodeIntIfPresent(forKeys: [.candidateCount, .candidate_count]) ?? 0
        selectedCount = try container.decodeIntIfPresent(forKeys: [.selectedCount, .selected_count]) ?? 0
        fallbackReason = try container.decodeStringIfPresent(forKeys: [.fallbackReason, .fallback_reason])
        generatedAt = try container.decodeStringIfPresent(forKeys: [.generatedAt, .generated_at]) ?? ""
        locale = try container.decodeStringIfPresent(forKeys: [.locale]) ?? DefaultLanguageProvider.shared.currentLanguageCode
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
