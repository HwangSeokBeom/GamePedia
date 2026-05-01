import Foundation

struct PushNotificationPayload: Hashable {
    enum Destination: Hashable {
        case notifications
        case gameDetail(Int)
        case reviewDetail(gameID: Int, reviewID: String?, commentID: String?)
        case friendRequests
        case profile(String?)
        case libraryCurator
    }

    let type: String?
    let notificationID: String?
    let reviewID: String?
    let commentID: String?
    let gameID: Int?
    let userID: String?
    let route: String?
    let source: String?
    let badge: Int?

    var routeTarget: String {
        route ?? type ?? "notification_list"
    }

    var destination: Destination {
        let normalizedRoute = routeTarget.lowercased()

        switch normalizedRoute {
        case "notification_list", "notifications":
            return .notifications
        case "game_detail", "game", "friend_liked_game_added", "friend_started_playing", "friend_recently_played":
            if let gameID {
                return .gameDetail(gameID)
            }
        case "review_detail", "review_thread", "review_liked", "review_comment_reply", "review_comment_like", "review_comment_dislike":
            if let gameID {
                return .reviewDetail(gameID: gameID, reviewID: reviewID, commentID: commentID)
            }
        case "friend_request", "friend_requests", "friend_request_received":
            return .friendRequests
        case "profile", "friend_profile":
            return .profile(userID)
        case "library_curator", "recommendation", "ai_recommendation":
            return .libraryCurator
        default:
            break
        }

        if let gameID {
            return .gameDetail(gameID)
        }

        if let userID {
            return .profile(userID)
        }

        return .notifications
    }

    static func parse(userInfo: [AnyHashable: Any]) -> PushNotificationPayload? {
        func string(_ keys: String...) -> String? {
            for key in keys {
                if let value = userInfo[key] as? String,
                   value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
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
                if let value = userInfo[key] as? NSNumber {
                    return value.intValue
                }
                if let value = userInfo[key] as? String,
                   let intValue = Int(value) {
                    return intValue
                }
            }
            return nil
        }

        let aps = userInfo["aps"] as? [String: Any]
        let type = string("type", "activityType", "eventType")
        let notificationID = string("notificationId", "notificationID", "id", "activityId", "eventId")
        let route = string("route", "routeTarget", "target")
        let reviewID = string("reviewId", "relatedReviewId")
        let commentID = string("commentId", "relatedCommentId")
        let gameID = int("gameId", "relatedGameId")
        let userID = string("userId", "relatedUserId")
        let source = string("source")
        let badge = int("badge") ?? (aps?["badge"] as? Int) ?? (aps?["badge"] as? NSNumber)?.intValue

        guard type != nil || notificationID != nil || route != nil || gameID != nil || userID != nil else {
            return nil
        }

        return PushNotificationPayload(
            type: type,
            notificationID: notificationID,
            reviewID: reviewID,
            commentID: commentID,
            gameID: gameID,
            userID: userID,
            route: route,
            source: source,
            badge: badge
        )
    }
}
