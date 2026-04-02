import Foundation

struct SocialActivityPushPayload: Hashable {
    let id: String
    let type: String
    let title: String
    let message: String
    let actorNickname: String?
    let actorAvatarURL: URL?
    let gameTitle: String?
    let gameCoverURL: URL?
    let relatedGameID: Int?
    let relatedUserID: String?
    let reviewID: String?

    var stableIdentity: String {
        if !id.isEmpty {
            return id
        }

        return [
            type,
            relatedUserID ?? "",
            relatedGameID.map(String.init) ?? "",
            reviewID ?? ""
        ].joined(separator: ":")
    }

    var route: SocialActivityRoute {
        let normalizedType = type.lowercased()

        switch normalizedType {
        case "friend_request", "friend_request_received":
            return .friendRequests
        case "review_created", "review_updated", "friend_wrote_review", "friend_review_reaction":
            if let relatedGameID {
                return .review(gameID: relatedGameID, reviewID: reviewID)
            }
        default:
            break
        }

        if let relatedGameID {
            return .gameDetail(relatedGameID)
        }

        if let relatedUserID {
            return .friendProfile(relatedUserID)
        }

        return .friendActivityFeed
    }

    var bannerPayload: SocialActivityBannerPayload {
        SocialActivityBannerPayload(
            id: stableIdentity,
            title: title,
            message: message,
            actorAvatarURL: actorAvatarURL,
            gameCoverURL: gameCoverURL,
            route: route
        )
    }

    static func parse(userInfo: [AnyHashable: Any]) -> SocialActivityPushPayload? {
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]

        func string(_ keys: String...) -> String? {
            for key in keys {
                if let value = userInfo[key] as? String, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return value
                }
                if let value = userInfo[key] as? NSNumber {
                    return value.stringValue
                }
            }
            return nil
        }

        func int(_ keys: String...) -> Int? {
            for key in keys {
                if let value = userInfo[key] as? Int {
                    return value
                }
                if let value = userInfo[key] as? String, let intValue = Int(value) {
                    return intValue
                }
                if let value = userInfo[key] as? NSNumber {
                    return value.intValue
                }
            }
            return nil
        }

        let type = string("type", "activityType", "eventType") ?? "generic"
        let title = string("title", "alertTitle")
            ?? (alert?["title"] as? String)
            ?? "친구 활동"
        let message = string("message", "body", "alertBody")
            ?? (alert?["body"] as? String)
            ?? ""

        if type == "generic", message.isEmpty, title == "친구 활동" {
            return nil
        }

        return SocialActivityPushPayload(
            id: string("activityId", "eventId", "id") ?? "",
            type: type,
            title: title,
            message: message,
            actorNickname: string("actorNickname", "nickname"),
            actorAvatarURL: string("actorAvatarUrl", "actorAvatarURL", "profileImageUrl").flatMap(URL.init(string:)),
            gameTitle: string("gameTitle", "relatedGameTitle"),
            gameCoverURL: string("gameCoverUrl", "gameCoverURL").flatMap(URL.init(string:)),
            relatedGameID: int("relatedGameId", "gameId"),
            relatedUserID: string("relatedUserId", "userId"),
            reviewID: string("reviewId")
        )
    }
}
