import XCTest
@testable import GamePedia

final class BackendContractTests: XCTestCase {
    func testCanonicalEndpointPathsMatchCrossPlatformContract() {
        XCTAssertEqual(Endpoint.recentPlays().path, "/users/me/recently-played")
        XCTAssertEqual(Endpoint.socialPrivacySettings.path, "/users/me/privacy")

        let privacyUpdate = UpdateSocialPrivacySettingsRequestDTO(
            isFriendsListPublic: true,
            isRecentPlayPublic: true,
            isLikedGamesPublic: false,
            isReviewsPublic: true
        )
        XCTAssertEqual(Endpoint.updateSocialPrivacySettings(body: privacyUpdate).path, "/users/me/privacy")
        XCTAssertEqual(Endpoint.mySteamLinkStatus.path, "/users/me/steam")
        XCTAssertEqual(Endpoint.importSteamFriends.path, "/users/me/friends/steam/import")
        XCTAssertEqual(
            Endpoint.friendRecommendations(userID: "00000000-0000-0000-0000-000000000001").path,
            "/users/00000000-0000-0000-0000-000000000001/friend-recommendations"
        )
        XCTAssertEqual(Endpoint.savePushToken(body: samplePushToken).method.rawValue, "PUT")
    }

    func testPrivacyRequestEncodesCanonicalKeysAndResponseDecodesThem() throws {
        let request = UpdateSocialPrivacySettingsRequestDTO(
            isFriendsListPublic: true,
            isRecentPlayPublic: false,
            isLikedGamesPublic: true,
            isReviewsPublic: false
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Bool]
        )

        XCTAssertEqual(
            object,
            [
                "showFriendsList": true,
                "showRecentlyPlayed": false,
                "showLikedGames": true,
                "showReviews": false
            ]
        )

        let response = try APIJSONCoding.makeDecoder().decode(
            FriendResponseEnvelopeDTO<SocialPrivacySettingsResponseDataDTO>.self,
            from: Data(
                """
                {
                  "success": true,
                  "data": {
                    "privacy": {
                      "showFriendsList": true,
                      "showRecentlyPlayed": false,
                      "showLikedGames": true,
                      "showReviews": false
                    },
                    "steamFriendsFeatureAvailable": true
                  }
                }
                """.utf8
            )
        )

        XCTAssertEqual(response.data.isFriendsListPublic, true)
        XCTAssertEqual(response.data.isRecentPlayPublic, false)
        XCTAssertEqual(response.data.isLikedGamesPublic, true)
        XCTAssertEqual(response.data.isReviewsPublic, false)
        XCTAssertEqual(response.data.steamFriendsFeatureAvailable, true)
    }

    func testRecentPlayDecoderAcceptsCanonicalGamesField() throws {
        let response = try APIJSONCoding.makeDecoder().decode(
            RecentGameListResponseDTO.self,
            from: Data(
                """
                {
                  "success": true,
                  "data": {
                    "games": [{
                      "externalGameId": "42",
                      "gameSource": "steam",
                      "name": "Example",
                      "lastPlayedAt": "2026-07-13T12:00:00.123Z",
                      "playtimeMinutes": 90
                    }],
                    "hasMoreRecentPlayed": false
                  }
                }
                """.utf8
            )
        )

        XCTAssertEqual(response.recentGames.count, 1)
        XCTAssertEqual(response.recentGames.first?.externalGameId, "42")
        XCTAssertEqual(response.recentGames.first?.recentPlaytimeMinutes, 90)
        XCTAssertEqual(response.hasMoreRecentPlayed, false)
    }

    func testSteamStatusRequiredBooleansAndISO8601DatesDecode() throws {
        let status = try APIJSONCoding.makeDecoder().decode(
            SteamLinkStatusDTO.self,
            from: Data(
                """
                {
                  "isLinked": false,
                  "steamId": null,
                  "steamId64": null,
                  "displayName": null,
                  "personaName": null,
                  "avatarUrl": null,
                  "profileUrl": null,
                  "canSync": false,
                  "canDisconnect": false,
                  "linkedAt": null,
                  "lastSteamSyncAt": null
                }
                """.utf8
            )
        )
        XCTAssertFalse(status.isLinked)
        XCTAssertFalse(status.canSync)
        XCTAssertFalse(status.canDisconnect)

        struct TimestampFixture: Decodable {
            let createdAt: Date
        }
        let fixture = try APIJSONCoding.makeDecoder().decode(
            TimestampFixture.self,
            from: Data(#"{"createdAt":"2026-07-13T12:00:00.123Z"}"#.utf8)
        )
        XCTAssertEqual(fixture.createdAt.timeIntervalSince1970, 1_783_944_000.123, accuracy: 0.001)
    }

    private var samplePushToken: PushTokenRequestDTO {
        PushTokenRequestDTO(
            token: String(repeating: "a", count: 20),
            platform: "ios",
            deviceId: "device",
            appVersion: "2.0.0",
            buildNumber: "1",
            environment: "dev"
        )
    }
}
