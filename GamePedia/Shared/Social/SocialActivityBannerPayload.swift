import Foundation

struct SocialActivityBannerPayload: Hashable {
    let id: String
    let title: String
    let message: String
    let actorAvatarURL: URL?
    let gameCoverURL: URL?
    let route: SocialActivityRoute
}
