import Foundation

// MARK: - UserProfileDTO

struct UserProfileDTO: Decodable {
    let id: Int
    let email: String?
    let name: String
    let handle: String              // e.g. "@ijunhyik_gamer"
    let avatarUrl: String?
    let badgeTitle: String?         // e.g. "Pro Reviewer"
    let translatedBadgeTitle: String?
    let selectedTitle: String?
    let selectedTitles: [String]
    let explicitSelected: Bool?
    let availableTitles: [String]
    let profileTags: [String]
    let friendCount: Int
    let likeCount: Int
    let playedGameCount: Int
    let writtenReviewCount: Int
    let wishlistCount: Int
    let recentPlayedPreview: [RecentGameDTO]
    let hasMoreRecentPlayed: Bool
    let recentPlayedCount: Int
    let recentPlayedSource: String?

    init(
        id: Int,
        email: String?,
        name: String,
        handle: String,
        avatarUrl: String?,
        badgeTitle: String?,
        translatedBadgeTitle: String?,
        selectedTitle: String?,
        selectedTitles: [String],
        explicitSelected: Bool?,
        availableTitles: [String],
        profileTags: [String],
        friendCount: Int,
        likeCount: Int,
        playedGameCount: Int,
        writtenReviewCount: Int,
        wishlistCount: Int,
        recentPlayedPreview: [RecentGameDTO],
        hasMoreRecentPlayed: Bool,
        recentPlayedCount: Int,
        recentPlayedSource: String?
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.handle = handle
        self.avatarUrl = avatarUrl
        self.badgeTitle = badgeTitle
        self.translatedBadgeTitle = translatedBadgeTitle
        self.selectedTitle = selectedTitle
        self.selectedTitles = selectedTitles
        self.explicitSelected = explicitSelected
        self.availableTitles = availableTitles
        self.profileTags = profileTags
        self.friendCount = friendCount
        self.likeCount = likeCount
        self.playedGameCount = playedGameCount
        self.writtenReviewCount = writtenReviewCount
        self.wishlistCount = wishlistCount
        self.recentPlayedPreview = recentPlayedPreview
        self.hasMoreRecentPlayed = hasMoreRecentPlayed
        self.recentPlayedCount = recentPlayedCount
        self.recentPlayedSource = recentPlayedSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.decodeInt(container, keys: [.id, .userId]) ?? 0
        email = Self.decodeString(container, keys: [.email])
        name = Self.decodeString(container, keys: [.name, .nickname]) ?? "GamePedia"
        handle = Self.decodeString(container, keys: [.handle]) ?? ""
        avatarUrl = Self.decodeString(container, keys: [.avatarUrl, .profileImageUrl])
        badgeTitle = Self.decodeString(container, keys: [.badgeTitle])
        translatedBadgeTitle = Self.decodeString(container, keys: [.translatedBadgeTitle])
        selectedTitle = Self.decodeString(container, keys: [.selectedTitle, .selectedBadgeTitle, .badgeTitle, .translatedBadgeTitle])
            ?? Self.decodeTitleObject(container, keys: [.selectedTitleObject, .selectedTitleMeta, .selectedTitle])
        selectedTitles = Self.decodeStringArray(container, keys: [.selectedTitles, .selectedTitleList, .selectedBadgeTitles])
        explicitSelected = Self.decodeBool(container, keys: [.explicitSelected, .hasExplicitSelection, .isExplicitSelected])
        availableTitles = Self.decodeStringArray(container, keys: [.availableTitles, .titles, .badgeTitles])
        profileTags = Self.decodeStringArray(container, keys: [.profileTags, .tasteTags, .tags])
        friendCount = Self.decodeInt(container, keys: [.friendCount, .friendsCount]) ?? 0
        likeCount = Self.decodeInt(container, keys: [.likeCount, .likesCount, .wishlistCount]) ?? 0
        playedGameCount = Self.decodeInt(container, keys: [.playedGameCount]) ?? 0
        writtenReviewCount = Self.decodeInt(container, keys: [.writtenReviewCount, .reviewCount]) ?? 0
        wishlistCount = Self.decodeInt(container, keys: [.wishlistCount, .likeCount, .likesCount]) ?? 0
        recentPlayedPreview = Self.decodeRecentGames(container, keys: [.recentPlayedPreview, .recentlyPlayed, .recentGames]) ?? []
        hasMoreRecentPlayed = Self.decodeBool(container, keys: [.hasMoreRecentPlayed, .hasMoreRecentPlays]) ?? false
        recentPlayedCount = Self.decodeInt(container, keys: [.recentPlayedCount, .previewCount]) ?? recentPlayedPreview.count
        recentPlayedSource = Self.decodeString(container, keys: [.recentPlayedSource, .previewSource])
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case email
        case name
        case nickname
        case handle
        case avatarUrl
        case profileImageUrl
        case badgeTitle
        case translatedBadgeTitle
        case selectedTitle
        case selectedTitles
        case selectedTitleList
        case explicitSelected
        case hasExplicitSelection
        case isExplicitSelected
        case selectedTitleObject
        case selectedTitleMeta
        case selectedBadgeTitle
        case selectedBadgeTitles
        case availableTitles
        case titles
        case badgeTitles
        case profileTags
        case tasteTags
        case tags
        case friendCount
        case friendsCount
        case likeCount
        case likesCount
        case playedGameCount
        case writtenReviewCount
        case reviewCount
        case wishlistCount
        case recentPlayedPreview
        case recentlyPlayed
        case recentGames
        case hasMoreRecentPlayed
        case hasMoreRecentPlays
        case recentPlayedCount
        case previewCount
        case recentPlayedSource
        case previewSource
    }

    private static func decodeString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(String.self, forKey: key),
               value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return value
            }
        }
        return nil
    }

    private static func decodeInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Int? {
        for key in keys {
            if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
                return intValue
            }
            if let stringValue = try? container.decodeIfPresent(String.self, forKey: key),
               let intValue = Int(stringValue) {
                return intValue
            }
        }
        return nil
    }

    private static func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Bool? {
        for key in keys {
            if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    private static func decodeStringArray(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> [String] {
        for key in keys {
            if let values = try? container.decodeIfPresent([String].self, forKey: key) {
                return values
            }
            if let values = try? container.decodeIfPresent([TitleListItemDTO].self, forKey: key) {
                return values.compactMap(\.resolvedTitle)
            }
        }
        return []
    }

    private static func decodeTitleObject(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(TitleListItemDTO.self, forKey: key),
               let resolvedTitle = value.resolvedTitle {
                return resolvedTitle
            }
        }
        return nil
    }

    private static func decodeRecentGames(
        _ container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> [RecentGameDTO]? {
        for key in keys {
            if let values = try? container.decodeIfPresent([RecentGameDTO].self, forKey: key) {
                return values
            }
        }
        return nil
    }
}

struct CurrentUserProfileResponseDTO: Decodable {
    let profile: UserProfileDTO

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let dataContainer = try? container.nestedContainer(keyedBy: NestedDataKeys.self, forKey: .data) {
                if let mergedProfile = try? Self.decodeMergedProfile(from: dataContainer) {
                    self.profile = mergedProfile
                    return
                }
                if let profile = try? dataContainer.decode(UserProfileDTO.self, forKey: .profile) {
                    self.profile = profile
                    return
                }
            }

            if let profile = try? container.decode(UserProfileDTO.self, forKey: .data) {
                self.profile = profile
                return
            }

            if let profile = try? container.decode(UserProfileDTO.self, forKey: .user) {
                self.profile = profile
                return
            }
        }

        self.profile = try UserProfileDTO(from: decoder)
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case user
    }

    private enum NestedDataKeys: String, CodingKey {
        case user
        case profile
        case summary
        case profileSummary
        case selectedTitle
        case selectedTitles
        case selectedTitleList
        case explicitSelected
        case hasExplicitSelection
        case isExplicitSelected
        case selectedTitleObject
        case selectedTitleMeta
        case selectedBadgeTitle
        case selectedBadgeTitles
        case availableTitles
        case titles
        case badgeTitles
        case profileTags
        case tasteTags
        case tags
        case friendCount
        case friendsCount
        case likeCount
        case likesCount
        case playedGameCount
        case writtenReviewCount
        case reviewCount
        case wishlistCount
        case recentPlayedPreview
        case recentlyPlayed
        case recentGames
        case hasMoreRecentPlayed
        case hasMoreRecentPlays
        case recentPlayedCount
        case previewCount
        case recentPlayedSource
        case previewSource
    }

    private static func decodeMergedProfile(
        from dataContainer: KeyedDecodingContainer<NestedDataKeys>
    ) throws -> UserProfileDTO {
        let user = try? dataContainer.decode(UserDTO.self, forKey: .user)
        let nestedProfile = try? dataContainer.decode(UserProfileDTO.self, forKey: .profile)
        let summaryProfile = try? dataContainer.decode(UserProfileDTO.self, forKey: .summary)
        let profileSummary = try? dataContainer.decode(UserProfileDTO.self, forKey: .profileSummary)
        let resolvedProfile = nestedProfile ?? summaryProfile ?? profileSummary
        let directAvailableTitles = (try? dataContainer.decodeIfPresent([String].self, forKey: .availableTitles))
        let legacyAvailableTitles = (try? dataContainer.decodeIfPresent([String].self, forKey: .titles))
        let badgeTitles = (try? dataContainer.decodeIfPresent([String].self, forKey: .badgeTitles))
        let availableTitleItems = (try? dataContainer.decodeIfPresent([TitleListItemDTO].self, forKey: .availableTitles))?.compactMap(\.resolvedTitle)
        let directProfileTags = (try? dataContainer.decodeIfPresent([String].self, forKey: .profileTags))
        let tasteTags = (try? dataContainer.decodeIfPresent([String].self, forKey: .tasteTags))
        let tags = (try? dataContainer.decodeIfPresent([String].self, forKey: .tags))
        let directRecentPlayedPreview = (try? dataContainer.decodeIfPresent([RecentGameDTO].self, forKey: .recentPlayedPreview))
        let recentlyPlayed = (try? dataContainer.decodeIfPresent([RecentGameDTO].self, forKey: .recentlyPlayed))
        let recentGames = (try? dataContainer.decodeIfPresent([RecentGameDTO].self, forKey: .recentGames))
        let selectedTitleObject = (try? dataContainer.decodeIfPresent(TitleListItemDTO.self, forKey: .selectedTitleObject))?.resolvedTitle
        let selectedTitleMeta = (try? dataContainer.decodeIfPresent(TitleListItemDTO.self, forKey: .selectedTitleMeta))?.resolvedTitle
        let directSelectedTitles = (try? dataContainer.decodeIfPresent([String].self, forKey: .selectedTitles))
        let selectedTitleList = (try? dataContainer.decodeIfPresent([String].self, forKey: .selectedTitleList))
        let selectedBadgeTitles = (try? dataContainer.decodeIfPresent([String].self, forKey: .selectedBadgeTitles))
        let selectedTitleItems = (try? dataContainer.decodeIfPresent([TitleListItemDTO].self, forKey: .selectedTitles))?.compactMap(\.resolvedTitle)
        let explicitSelected =
            (try? dataContainer.decodeIfPresent(Bool.self, forKey: .explicitSelected)) ??
            (try? dataContainer.decodeIfPresent(Bool.self, forKey: .hasExplicitSelection)) ??
            (try? dataContainer.decodeIfPresent(Bool.self, forKey: .isExplicitSelected)) ??
            resolvedProfile?.explicitSelected

        let selectedTitle =
            (try? dataContainer.decodeIfPresent(String.self, forKey: .selectedTitle)) ??
            selectedTitleObject ??
            selectedTitleMeta ??
            (try? dataContainer.decodeIfPresent(String.self, forKey: .selectedBadgeTitle)) ??
            resolvedProfile?.selectedTitle ??
            resolvedProfile?.translatedBadgeTitle ??
            resolvedProfile?.badgeTitle

        let selectedTitles =
            directSelectedTitles ??
            selectedTitleList ??
            selectedBadgeTitles ??
            selectedTitleItems ??
            resolvedProfile?.selectedTitles ??
            selectedTitle.map { [$0] } ??
            []

        let availableTitles = directAvailableTitles ?? legacyAvailableTitles ?? badgeTitles ?? availableTitleItems ?? resolvedProfile?.availableTitles ?? []

        let profileTags = directProfileTags ?? tasteTags ?? tags ?? resolvedProfile?.profileTags ?? []

        let recentPlayedPreview = directRecentPlayedPreview ?? recentlyPlayed ?? recentGames ?? resolvedProfile?.recentPlayedPreview ?? []

        let friendCount =
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .friendCount)) ??
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .friendsCount)) ??
            resolvedProfile?.friendCount ??
            0

        let likeCount =
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .likeCount)) ??
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .likesCount)) ??
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .wishlistCount)) ??
            resolvedProfile?.likeCount ??
            resolvedProfile?.wishlistCount ??
            0

        let playedGameCount =
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .playedGameCount)) ??
            resolvedProfile?.playedGameCount ??
            recentPlayedPreview.count

        let writtenReviewCount =
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .writtenReviewCount)) ??
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .reviewCount)) ??
            resolvedProfile?.writtenReviewCount ??
            0

        let wishlistCount =
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .wishlistCount)) ??
            resolvedProfile?.wishlistCount ??
            likeCount

        let hasMoreRecentPlayed =
            (try? dataContainer.decodeIfPresent(Bool.self, forKey: .hasMoreRecentPlayed)) ??
            (try? dataContainer.decodeIfPresent(Bool.self, forKey: .hasMoreRecentPlays)) ??
            resolvedProfile?.hasMoreRecentPlayed ??
            false

        let recentPlayedCount =
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .recentPlayedCount)) ??
            (try? dataContainer.decodeIfPresent(Int.self, forKey: .previewCount)) ??
            resolvedProfile?.recentPlayedCount ??
            recentPlayedPreview.count

        let recentPlayedSource =
            (try? dataContainer.decodeIfPresent(String.self, forKey: .recentPlayedSource)) ??
            (try? dataContainer.decodeIfPresent(String.self, forKey: .previewSource)) ??
            resolvedProfile?.recentPlayedSource

        return UserProfileDTO(
            id: resolvedProfile?.id ?? Int(user?.id ?? "") ?? 0,
            email: resolvedProfile?.email ?? user?.email,
            name: resolvedProfile?.name ?? user?.nickname ?? "GamePedia",
            handle: resolvedProfile?.handle ?? "",
            avatarUrl: resolvedProfile?.avatarUrl ?? user?.profileImageUrl,
            badgeTitle: resolvedProfile?.badgeTitle,
            translatedBadgeTitle: resolvedProfile?.translatedBadgeTitle,
            selectedTitle: selectedTitle,
            selectedTitles: selectedTitles,
            explicitSelected: explicitSelected,
            availableTitles: availableTitles,
            profileTags: profileTags,
            friendCount: friendCount,
            likeCount: likeCount,
            playedGameCount: playedGameCount,
            writtenReviewCount: writtenReviewCount,
            wishlistCount: wishlistCount,
            recentPlayedPreview: recentPlayedPreview,
            hasMoreRecentPlayed: hasMoreRecentPlayed,
            recentPlayedCount: recentPlayedCount,
            recentPlayedSource: recentPlayedSource
        )
    }
}

private struct TitleListItemDTO: Decodable {
    let title: String?
    let name: String?
    let label: String?
    let isSelected: Bool?

    var resolvedTitle: String? {
        let value = title ?? name ?? label
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - RecentGameListResponseDTO

struct RecentGameListResponseDTO: Decodable {
    let recentGames: [RecentGameDTO]
    let hasMoreRecentPlayed: Bool?

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let dataContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data) {
                recentGames =
                    (try? dataContainer.decodeIfPresent([RecentGameDTO].self, forKey: .recentGames)) ??
                    (try? dataContainer.decodeIfPresent([RecentGameDTO].self, forKey: .recentlyPlayed)) ??
                    (try? dataContainer.decodeIfPresent([RecentGameDTO].self, forKey: .recentPlayedPreview)) ??
                    []
                hasMoreRecentPlayed =
                    (try? dataContainer.decodeIfPresent(Bool.self, forKey: .hasMoreRecentPlayed)) ??
                    (try? dataContainer.decodeIfPresent(Bool.self, forKey: .hasMoreRecentPlays))
                return
            }

            recentGames =
                (try? container.decodeIfPresent([RecentGameDTO].self, forKey: .recentGames)) ??
                (try? container.decodeIfPresent([RecentGameDTO].self, forKey: .recentlyPlayed)) ??
                (try? container.decodeIfPresent([RecentGameDTO].self, forKey: .recentPlayedPreview)) ??
                []
            hasMoreRecentPlayed =
                (try? container.decodeIfPresent(Bool.self, forKey: .hasMoreRecentPlayed)) ??
                (try? container.decodeIfPresent(Bool.self, forKey: .hasMoreRecentPlays))
            return
        }

        if let singleValueContainer = try? decoder.singleValueContainer(),
           let recentGames = try? singleValueContainer.decode([RecentGameDTO].self) {
            self.recentGames = recentGames
            self.hasMoreRecentPlayed = nil
            return
        }

        recentGames = []
        hasMoreRecentPlayed = nil
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case recentGames
        case recentlyPlayed
        case recentPlayedPreview
        case hasMoreRecentPlayed
        case hasMoreRecentPlays
    }
}

// MARK: - RecentGameDTO

struct RecentGameDTO: Decodable {
    let gameId: Int
    let igdbGameId: Int?
    let externalGameId: String?
    let detailAvailable: Bool?
    let title: String
    let titleKo: String?
    let translatedTitle: String?
    let coverImageUrl: String
    let userRating: Double?
    let aggregatedRating: Double?
    let totalRating: Double?
    let lastPlayedAt: String        // ISO8601 string
    let lastPlayedAtSource: String?
    let hasReliableLastPlayedAt: Bool?
    let recentPlaytimeMinutes: Int?
    let fallbackReason: String?

    init(
        gameId: Int,
        igdbGameId: Int?,
        externalGameId: String?,
        detailAvailable: Bool?,
        title: String,
        titleKo: String?,
        translatedTitle: String?,
        coverImageUrl: String,
        userRating: Double?,
        aggregatedRating: Double?,
        totalRating: Double?,
        lastPlayedAt: String,
        lastPlayedAtSource: String?,
        hasReliableLastPlayedAt: Bool?,
        recentPlaytimeMinutes: Int?,
        fallbackReason: String?
    ) {
        self.gameId = gameId
        self.igdbGameId = igdbGameId
        self.externalGameId = externalGameId
        self.detailAvailable = detailAvailable
        self.title = title
        self.titleKo = titleKo
        self.translatedTitle = translatedTitle
        self.coverImageUrl = coverImageUrl
        self.userRating = userRating
        self.aggregatedRating = aggregatedRating
        self.totalRating = totalRating
        self.lastPlayedAt = lastPlayedAt
        self.lastPlayedAtSource = lastPlayedAtSource
        self.hasReliableLastPlayedAt = hasReliableLastPlayedAt
        self.recentPlaytimeMinutes = recentPlaytimeMinutes
        self.fallbackReason = fallbackReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nestedGame = try? container.decode(NestedGameDTO.self, forKey: .game) {
            gameId = nestedGame.id ?? nestedGame.igdbGameId ?? 0
            igdbGameId = nestedGame.id ?? nestedGame.igdbGameId
            externalGameId = nestedGame.externalGameId
            detailAvailable = nestedGame.detailAvailable
            title = nestedGame.name ?? nestedGame.title ?? "이름 없는 게임"
            titleKo = nestedGame.titleKo
            translatedTitle = nestedGame.translatedTitle
            coverImageUrl = nestedGame.coverImageUrl ?? nestedGame.coverUrl ?? ""
            aggregatedRating = nestedGame.aggregatedRating
            totalRating = nestedGame.totalRating
        } else {
            gameId = (try? container.decodeIfPresent(Int.self, forKey: .gameId)) ??
                (try? container.decodeIfPresent(Int.self, forKey: .igdbGameId)) ??
                (try? container.decodeIfPresent(Int.self, forKey: .id)) ??
                0
            igdbGameId = (try? container.decodeIfPresent(Int.self, forKey: .igdbGameId)) ?? (gameId > 0 ? gameId : nil)
            externalGameId = Self.decodeString(container, key: .externalGameId)
            detailAvailable = try? container.decodeIfPresent(Bool.self, forKey: .detailAvailable)
            title = (try? container.decodeIfPresent(String.self, forKey: .title)) ??
                (try? container.decodeIfPresent(String.self, forKey: .name)) ??
                "이름 없는 게임"
            titleKo = try? container.decodeIfPresent(String.self, forKey: .titleKo)
            translatedTitle = try? container.decodeIfPresent(String.self, forKey: .translatedTitle)
            coverImageUrl = (try? container.decodeIfPresent(String.self, forKey: .coverImageUrl)) ??
                (try? container.decodeIfPresent(String.self, forKey: .coverUrl)) ??
                ""
            aggregatedRating =
                (try? container.decodeIfPresent(Double.self, forKey: .aggregatedRating)) ??
                (try? container.decodeIfPresent(Double.self, forKey: .aggregated_rating))
            totalRating =
                (try? container.decodeIfPresent(Double.self, forKey: .totalRating)) ??
                (try? container.decodeIfPresent(Double.self, forKey: .total_rating))
        }

        userRating = (try? container.decodeIfPresent(Double.self, forKey: .userRating)) ??
            (try? container.decodeIfPresent(Double.self, forKey: .user_rating))
        lastPlayedAt =
            Self.decodeString(container, key: .lastPlayedAt) ??
            Self.decodeString(container, key: .playedAt) ??
            Self.decodeString(container, key: .last_played_at) ??
            Self.decodeString(container, key: .played_at) ??
            ""
        lastPlayedAtSource =
            Self.decodeString(container, key: .lastPlayedAtSource) ??
            Self.decodeString(container, key: .playedAtSource) ??
            Self.decodeString(container, key: .last_played_at_source) ??
            Self.decodeString(container, key: .played_at_source)
        hasReliableLastPlayedAt =
            (try? container.decodeIfPresent(Bool.self, forKey: .hasReliableLastPlayedAt)) ??
            (try? container.decodeIfPresent(Bool.self, forKey: .isReliableLastPlayedAt)) ??
            (try? container.decodeIfPresent(Bool.self, forKey: .has_reliable_last_played_at)) ??
            (try? container.decodeIfPresent(Bool.self, forKey: .is_reliable_last_played_at))
        recentPlaytimeMinutes =
            (try? container.decodeIfPresent(Int.self, forKey: .recentPlaytimeMinutes)) ??
            (try? container.decodeIfPresent(Int.self, forKey: .recent_playtime_minutes)) ??
            (try? container.decodeIfPresent(Int.self, forKey: .playtimeMinutes)) ??
            (try? container.decodeIfPresent(Int.self, forKey: .playtime_minutes))
        fallbackReason =
            Self.decodeString(container, key: .fallbackReason) ??
            Self.decodeString(container, key: .fallback_reason)
    }

    private static func decodeString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            if floor(doubleValue) == doubleValue {
                return String(Int(doubleValue))
            }
            return String(doubleValue)
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case gameId
        case igdbGameId
        case id
        case externalGameId
        case detailAvailable
        case title
        case name
        case titleKo
        case translatedTitle
        case coverImageUrl
        case coverUrl
        case userRating
        case user_rating
        case rating
        case aggregatedRating
        case aggregated_rating
        case totalRating
        case total_rating
        case lastPlayedAt
        case lastPlayedAtSource
        case playedAtSource
        case last_played_at
        case played_at
        case last_played_at_source
        case played_at_source
        case hasReliableLastPlayedAt
        case isReliableLastPlayedAt
        case has_reliable_last_played_at
        case is_reliable_last_played_at
        case recentPlaytimeMinutes
        case recent_playtime_minutes
        case playtimeMinutes
        case playtime_minutes
        case fallbackReason
        case fallback_reason
        case playedAt
        case game
    }
}

private struct NestedGameDTO: Decodable {
    let id: Int?
    let igdbGameId: Int?
    let externalGameId: String?
    let detailAvailable: Bool?
    let name: String?
    let title: String?
    let titleKo: String?
    let translatedTitle: String?
    let coverImageUrl: String?
    let coverUrl: String?
    let aggregatedRating: Double?
    let totalRating: Double?
}
