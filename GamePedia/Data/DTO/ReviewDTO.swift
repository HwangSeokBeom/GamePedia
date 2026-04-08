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
    let likeCount: Int
    let commentCount: Int
    let isLikedByCurrentUser: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case gameId
        case game_id
        case rating
        case content
        case createdAt
        case created_at
        case updatedAt
        case updated_at
        case author
        case authorId
        case author_id
        case authorNickname
        case author_nickname
        case authorProfileImageUrl
        case author_profile_image_url
        case isMine
        case is_mine
        case likeCount
        case likesCount
        case like_count
        case likes_count
        case commentCount
        case commentsCount
        case comment_count
        case comments_count
        case isLikedByCurrentUser
        case is_liked
        case likedByCurrentUser
        case liked_by_current_user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        gameId = try Self.decodeRequiredString(from: container, primaryKey: .gameId, fallbackKey: .game_id)
        rating = try container.decode(Double.self, forKey: .rating)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try Self.decodeRequiredString(from: container, primaryKey: .createdAt, fallbackKey: .created_at)
        updatedAt = try Self.decodeRequiredString(from: container, primaryKey: .updatedAt, fallbackKey: .updated_at)
        if let nestedAuthor = try? container.decode(ReviewAuthorDTO.self, forKey: .author) {
            author = nestedAuthor
        } else {
            author = ReviewAuthorDTO(
                id: try Self.decodeRequiredString(
                    from: container,
                    primaryKey: .authorId,
                    fallbackKey: .author_id
                ),
                nickname: try Self.decodeRequiredString(
                    from: container,
                    primaryKey: .authorNickname,
                    fallbackKey: .author_nickname
                ),
                profileImageUrl: Self.decodeOptionalString(
                    from: container,
                    primaryKey: .authorProfileImageUrl,
                    fallbackKey: .author_profile_image_url
                )
            )
        }
        isMine =
            (try? container.decode(Bool.self, forKey: .isMine)) ??
            (try? container.decode(Bool.self, forKey: .is_mine)) ??
            false
        likeCount =
            (try? container.decode(Int.self, forKey: .likeCount)) ??
            (try? container.decode(Int.self, forKey: .likesCount)) ??
            (try? container.decode(Int.self, forKey: .like_count)) ??
            (try? container.decode(Int.self, forKey: .likes_count)) ??
            0
        commentCount =
            (try? container.decode(Int.self, forKey: .commentCount)) ??
            (try? container.decode(Int.self, forKey: .commentsCount)) ??
            (try? container.decode(Int.self, forKey: .comment_count)) ??
            (try? container.decode(Int.self, forKey: .comments_count)) ??
            0
        isLikedByCurrentUser =
            (try? container.decode(Bool.self, forKey: .isLikedByCurrentUser)) ??
            (try? container.decode(Bool.self, forKey: .is_liked)) ??
            (try? container.decode(Bool.self, forKey: .likedByCurrentUser)) ??
            (try? container.decode(Bool.self, forKey: .liked_by_current_user)) ??
            false
    }

    private static func decodeRequiredString(
        from container: KeyedDecodingContainer<CodingKeys>,
        primaryKey: CodingKeys,
        fallbackKey: CodingKeys
    ) throws -> String {
        if let value = try container.decodeIfPresent(String.self, forKey: primaryKey) {
            return value
        }
        return try container.decode(String.self, forKey: fallbackKey)
    }

    private static func decodeOptionalString(
        from container: KeyedDecodingContainer<CodingKeys>,
        primaryKey: CodingKeys,
        fallbackKey: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: primaryKey) {
            return value
        }
        return try? container.decodeIfPresent(String.self, forKey: fallbackKey)
    }
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

struct ReviewLikeResponseDataDTO: Decodable {
    let reviewId: String
    let likeCount: Int
    let isLikedByCurrentUser: Bool

    private enum CodingKeys: String, CodingKey {
        case reviewId
        case likeCount
        case like_count
        case viewerHasLiked
        case isLikedByCurrentUser
        case likedByCurrentUser
        case liked_by_current_user
        case isLiked
        case is_liked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reviewId = try container.decode(String.self, forKey: .reviewId)
        likeCount =
            (try? container.decode(Int.self, forKey: .likeCount)) ??
            (try? container.decode(Int.self, forKey: .like_count)) ??
            0
        isLikedByCurrentUser =
            (try? container.decode(Bool.self, forKey: .isLikedByCurrentUser)) ??
            (try? container.decode(Bool.self, forKey: .viewerHasLiked)) ??
            (try? container.decode(Bool.self, forKey: .likedByCurrentUser)) ??
            (try? container.decode(Bool.self, forKey: .liked_by_current_user)) ??
            (try? container.decode(Bool.self, forKey: .isLiked)) ??
            (try? container.decode(Bool.self, forKey: .is_liked)) ??
            false
    }
}
