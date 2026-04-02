import Foundation

protocol FriendRepository {
    func searchFriends(keyword: String) async throws -> [FriendUserSummary]
    func fetchReceivedFriendRequests() async throws -> [FriendRequest]
    func fetchSentFriendRequests() async throws -> [FriendRequest]
    func sendFriendRequest(userID: String) async throws
    func acceptFriendRequest(requestID: String) async throws
    func rejectFriendRequest(requestID: String) async throws
    func cancelFriendRequest(requestID: String) async throws
    func fetchFriends() async throws -> [FriendUserSummary]
    func fetchSteamFriends() async throws -> (friends: [SteamFriend], isAvailable: Bool, isLimitedByPrivacy: Bool, syncWarningCode: String?)
    func fetchFriendProfile(userID: String) async throws -> FriendProfile
    func fetchFriendActivityFeed(cursor: String?) async throws -> FriendActivityFeedPage
    func fetchFriendRecommendations(userID: String) async throws -> [FriendRecommendation]
    func removeFriend(userID: String) async throws
    func blockUser(userID: String) async throws
    func fetchSocialPrivacySettings() async throws -> SocialPrivacySettings
    func updateSocialPrivacySettings(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings
    func importSteamFriends() async throws
}
