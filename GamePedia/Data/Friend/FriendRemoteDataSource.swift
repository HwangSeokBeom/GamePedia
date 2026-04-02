import Foundation

protocol FriendRemoteDataSource {
    func searchFriends(keyword: String) async throws -> FriendSearchResponseDataDTO
    func fetchFriendRequests(kind: FriendRequestListKind) async throws -> FriendRequestsResponseDataDTO
    func sendFriendRequest(userID: String) async throws
    func acceptFriendRequest(requestID: String) async throws
    func rejectFriendRequest(requestID: String) async throws
    func cancelFriendRequest(requestID: String) async throws
    func fetchFriends() async throws -> FriendsListResponseDataDTO
    func fetchSteamFriends() async throws -> SteamFriendsResponseDataDTO
    func fetchFriendProfile(userID: String) async throws -> FriendProfileResponseDataDTO
    func fetchFriendActivityFeed(cursor: String?) async throws -> FriendActivityFeedResponseDataDTO
    func fetchFriendRecommendations(userID: String) async throws -> FriendRecommendationsResponseDataDTO
    func removeFriend(userID: String) async throws
    func blockUser(userID: String) async throws
    func fetchSocialPrivacySettings() async throws -> SocialPrivacySettingsResponseDataDTO
    func updateSocialPrivacySettings(_ payload: UpdateSocialPrivacySettingsRequestDTO) async throws -> SocialPrivacySettingsResponseDataDTO
    func importSteamFriends() async throws
}

final class DefaultFriendRemoteDataSource: FriendRemoteDataSource {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func searchFriends(keyword: String) async throws -> FriendSearchResponseDataDTO {
        print("[Friend] request endpoint=GET /users/search keyword=\(keyword)")
        let response = try await apiClient.request(
            .searchFriends(keyword: keyword),
            as: FriendResponseEnvelopeDTO<FriendSearchResponseDataDTO>.self
        )
        return response.data
    }

    func fetchFriendRequests(kind: FriendRequestListKind) async throws -> FriendRequestsResponseDataDTO {
        let path = kind == .received ? "/users/me/friend-requests/received" : "/users/me/friend-requests/sent"
        print("[Friend] request endpoint=GET \(path)")
        let response = try await apiClient.request(
            .myFriendRequests(kind: kind),
            as: FriendResponseEnvelopeDTO<FriendRequestsResponseDataDTO>.self
        )
        print("[Friend] response endpoint=GET \(path) success count=\(response.data.requests.count)")
        return response.data
    }

    func sendFriendRequest(userID: String) async throws {
        print("[Friend] request endpoint=POST /users/me/friend-requests toUserId=\(userID)")
        try await apiClient.requestVoid(.sendFriendRequest(body: SendFriendRequestDTO(toUserId: userID)))
    }

    func acceptFriendRequest(requestID: String) async throws {
        print("[Friend] request endpoint=PATCH /users/me/friend-requests/\(requestID)/accept")
        try await apiClient.requestVoid(.acceptFriendRequest(requestID: requestID))
    }

    func rejectFriendRequest(requestID: String) async throws {
        print("[Friend] request endpoint=PATCH /users/me/friend-requests/\(requestID)/reject")
        try await apiClient.requestVoid(.rejectFriendRequest(requestID: requestID))
    }

    func cancelFriendRequest(requestID: String) async throws {
        print("[Friend] request endpoint=DELETE /users/me/friend-requests/\(requestID)")
        try await apiClient.requestVoid(.cancelFriendRequest(requestID: requestID))
    }

    func fetchFriends() async throws -> FriendsListResponseDataDTO {
        print("[Friend] request endpoint=GET /users/me/friends")
        let response = try await apiClient.request(
            .myFriends,
            as: FriendResponseEnvelopeDTO<FriendsListResponseDataDTO>.self
        )
        print("[Friend] response endpoint=GET /users/me/friends success count=\(response.data.friends.count)")
        return response.data
    }

    func fetchSteamFriends() async throws -> SteamFriendsResponseDataDTO {
        print("[Friend] request endpoint=GET /users/me/steam-friends")
        let response = try await apiClient.request(
            .mySteamFriends,
            as: FriendResponseEnvelopeDTO<SteamFriendsResponseDataDTO>.self
        )
        print(
            "[Friend] response endpoint=GET /users/me/steam-friends success count=\(response.data.friends.count) " +
            "available=\(response.data.steamFriendsAvailable ?? false) privacy=\(response.data.steamFriendsLimitedByPrivacy ?? false)"
        )
        return response.data
    }

    func fetchFriendProfile(userID: String) async throws -> FriendProfileResponseDataDTO {
        print("[Friend] request endpoint=GET /users/\(userID)/profile")
        let response = try await apiClient.request(
            .friendProfile(userID: userID),
            as: FriendResponseEnvelopeDTO<FriendProfileResponseDataDTO>.self
        )
        return response.data
    }

    func fetchFriendActivityFeed(cursor: String?) async throws -> FriendActivityFeedResponseDataDTO {
        print("[Friend] request endpoint=GET /users/me/friends/activity cursor=\(cursor ?? "nil")")
        let response = try await apiClient.request(
            .friendActivityFeed(cursor: cursor),
            as: FriendResponseEnvelopeDTO<FriendActivityFeedResponseDataDTO>.self
        )
        print(
            "[Friend] response endpoint=GET /users/me/friends/activity success " +
            "count=\(response.data.activities.count) nextCursor=\(response.data.nextCursor ?? "nil")"
        )
        return response.data
    }

    func fetchFriendRecommendations(userID: String) async throws -> FriendRecommendationsResponseDataDTO {
        print("[Friend] request endpoint=GET /users/\(userID)/friend-recommendations")
        let response = try await apiClient.request(
            .friendRecommendations(userID: userID),
            as: FriendResponseEnvelopeDTO<FriendRecommendationsResponseDataDTO>.self
        )
        return response.data
    }

    func removeFriend(userID: String) async throws {
        print("[Friend] request endpoint=DELETE /users/me/friends/\(userID)")
        try await apiClient.requestVoid(.removeFriend(userID: userID))
    }

    func blockUser(userID: String) async throws {
        print("[Friend] request endpoint=POST /users/me/blocks userId=\(userID)")
        try await apiClient.requestVoid(.blockUser(body: BlockUserRequestDTO(userId: userID)))
    }

    func fetchSocialPrivacySettings() async throws -> SocialPrivacySettingsResponseDataDTO {
        print("[Friend] request endpoint=GET /users/me/privacy-settings")
        let response = try await apiClient.request(
            .socialPrivacySettings,
            as: FriendResponseEnvelopeDTO<SocialPrivacySettingsResponseDataDTO>.self
        )
        return response.data
    }

    func updateSocialPrivacySettings(_ payload: UpdateSocialPrivacySettingsRequestDTO) async throws -> SocialPrivacySettingsResponseDataDTO {
        print("[Friend] request endpoint=PATCH /users/me/privacy-settings")
        let response = try await apiClient.request(
            .updateSocialPrivacySettings(body: payload),
            as: FriendResponseEnvelopeDTO<SocialPrivacySettingsResponseDataDTO>.self
        )
        return response.data
    }

    func importSteamFriends() async throws {
        print("[Friend] request endpoint=POST /users/me/friends/steam/import")
        try await apiClient.requestVoid(.importSteamFriends)
    }
}
