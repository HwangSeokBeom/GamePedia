// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen
// Developer guideline:
// 1. Add keys to GamePedia/Resources/Localization/<lang>.lproj/Localizable.strings(.stringsdict).
// 2. Regenerate this file with `swiftgen config run --config SwiftGen/swiftgen.yml`.
// 3. For dynamic text, prefer localized format/plural keys or .stringsdict entries instead of concatenating strings in code.
// 4. Localize only app UI text. Do not route game titles, developer names, platform names, or API content strings through L10n.

import Foundation

enum L10n {
  enum App {
    static let name = L10n.tr("Localizable", "app.name")
  }

  enum Splash {
    static let subtitle = L10n.tr("Localizable", "splash.subtitle")
  }

  enum Common {
    enum Button {
      static let confirm = L10n.tr("Localizable", "common.button.confirm")
      static let cancel = L10n.tr("Localizable", "common.button.cancel")
      static let retry = L10n.tr("Localizable", "common.button.retry")
      static let seeAll = L10n.tr("Localizable", "common.button.seeAll")
      static let delete = L10n.tr("Localizable", "common.button.delete")
      static let save = L10n.tr("Localizable", "common.button.save")
      static let disconnect = L10n.tr("Localizable", "common.button.disconnect")
      static let connect = L10n.tr("Localizable", "common.button.connect")
      static let openGuide = L10n.tr("Localizable", "common.button.openGuide")
      static let write = L10n.tr("Localizable", "common.button.write")
    }

    enum State {
      static let loading = L10n.tr("Localizable", "common.state.loading")
      static let empty = L10n.tr("Localizable", "common.state.empty")
    }

    enum Error {
      static let title = L10n.tr("Localizable", "common.error.title")
      static let network = L10n.tr("Localizable", "common.error.network")
      static let unknown = L10n.tr("Localizable", "common.error.unknown")
      static let invalidRequest = L10n.tr("Localizable", "common.error.invalidRequest")
      static let server = L10n.tr("Localizable", "common.error.server")
      static let gameIdInvalid = L10n.tr("Localizable", "common.error.gameIdInvalid")
      static let tryAgain = L10n.tr("Localizable", "common.error.tryAgain")
      static let invalidURL = L10n.tr("Localizable", "common.error.invalidURL")
      static let noData = L10n.tr("Localizable", "common.error.noData")
      static let unauthorized = L10n.tr("Localizable", "common.error.unauthorized")

      static func serverStatus(_ p1: Int, _ p2: String) -> String {
        L10n.tr("Localizable", "common.error.serverStatus", p1, p2)
      }

      static func decodingFailed(_ p1: String) -> String {
        L10n.tr("Localizable", "common.error.decodingFailed", p1)
      }

      static func unknownWithMessage(_ p1: String) -> String {
        L10n.tr("Localizable", "common.error.unknownWithMessage", p1)
      }
    }

    enum Label {
      static let noRating = L10n.tr("Localizable", "common.label.noRating")
      static let noDescription = L10n.tr("Localizable", "common.label.noDescription")
      static let other = L10n.tr("Localizable", "common.label.other")
      static let untitledGame = L10n.tr("Localizable", "common.label.untitledGame")
    }

    enum Section {
      static let account = L10n.tr("Localizable", "common.section.account")
      static let service = L10n.tr("Localizable", "common.section.service")
      static let support = L10n.tr("Localizable", "common.section.support")
    }

    enum Time {
      static let justNow = L10n.tr("Localizable", "common.time.justNow")
    }

    enum Format {
      static func lastSync(_ p1: String) -> String {
        L10n.tr("Localizable", "common.format.lastSync", p1)
      }
    }

    enum Count {
      static func games(_ p1: Int) -> String {
        L10n.tr("Localizable", "common.count.games", p1)
      }

      static func reviews(_ p1: Int) -> String {
        L10n.tr("Localizable", "common.count.reviews", p1)
      }

      static func friends(_ p1: Int) -> String {
        L10n.tr("Localizable", "common.count.friends", p1)
      }
    }
  }

  enum Home {
    enum Tab {
      static let title = L10n.tr("Localizable", "home.tab.title")
    }

    static let searchHint = L10n.tr("Localizable", "home.searchHint")

    enum Section {
      static let highlights = L10n.tr("Localizable", "home.section.highlights")
      static let popular = L10n.tr("Localizable", "home.section.popular")
      static let recommended = L10n.tr("Localizable", "home.section.recommended")
      static let todayRecommendation = L10n.tr("Localizable", "home.section.todayRecommendation")
      static let trending = L10n.tr("Localizable", "home.section.trending")
    }

    enum List {
      static let recommendation = L10n.tr("Localizable", "home.list.recommendation")
      static let popular = L10n.tr("Localizable", "home.list.popular")
      static let trending = L10n.tr("Localizable", "home.list.trending")
    }

    enum Empty {
      static let recommendation = L10n.tr("Localizable", "home.empty.recommendation")
      static let popular = L10n.tr("Localizable", "home.empty.popular")
      static let trending = L10n.tr("Localizable", "home.empty.trending")
    }
  }

  enum Search {
    enum Tab {
      static let title = L10n.tr("Localizable", "search.tab.title")
    }

    static let placeholder = L10n.tr("Localizable", "search.placeholder")

    enum Empty {
      static let noResults = L10n.tr("Localizable", "search.empty.noResults")
    }

    enum Filter {
      static let all = L10n.tr("Localizable", "search.filter.all")
    }

    enum Count {
      static func results(_ p1: Int) -> String {
        L10n.tr("Localizable", "search.count.results", p1)
      }
    }
  }

  enum Detail {
    enum Section {
      static let description = L10n.tr("Localizable", "detail.section.description")
      static let userReviews = L10n.tr("Localizable", "detail.section.userReviews")
    }

    enum Label {
      static let rating = L10n.tr("Localizable", "detail.label.rating")
      static let genres = L10n.tr("Localizable", "detail.label.genres")
      static let platforms = L10n.tr("Localizable", "detail.label.platforms")
    }

    enum Stats {
      static let playtime = L10n.tr("Localizable", "detail.stats.playtime")
      static let reviews = L10n.tr("Localizable", "detail.stats.reviews")
    }

    enum Button {
      static let writeReview = L10n.tr("Localizable", "detail.button.writeReview")
      static let favorite = L10n.tr("Localizable", "detail.button.favorite")
      static let favorited = L10n.tr("Localizable", "detail.button.favorited")
      static let editReview = L10n.tr("Localizable", "detail.button.editReview")
    }

    enum Review {
      static let none = L10n.tr("Localizable", "detail.review.none")
      static let userReviews = L10n.tr("Localizable", "detail.review.userReviews")
    }

    enum Fallback {
      static let note = L10n.tr("Localizable", "detail.fallback.note")
    }

    enum SteamReview {
      static let badge = L10n.tr("Localizable", "detail.steamReview.badge")
      static let helper = L10n.tr("Localizable", "detail.steamReview.helper")
      static let cta = L10n.tr("Localizable", "detail.steamReview.cta")
    }
  }

  enum Library {
    enum Tab {
      static let title = L10n.tr("Localizable", "library.tab.title")
    }

    enum Navigation {
      static let title = L10n.tr("Localizable", "library.navigation.title")
    }

    enum Section {
      static let recentlyPlayed = L10n.tr("Localizable", "library.section.recentlyPlayed")
      static let playing = L10n.tr("Localizable", "library.section.playing")
      static let owned = L10n.tr("Localizable", "library.section.owned")
      static let wishlist = L10n.tr("Localizable", "library.section.wishlist")
      static let friendRecommendations = L10n.tr("Localizable", "library.section.friendRecommendations")
      static let recentlyPlayedGames = L10n.tr("Localizable", "library.section.recentlyPlayedGames")
      static let playtimeRecommendations = L10n.tr("Localizable", "library.section.playtimeRecommendations")
      static let recentlyReviewed = L10n.tr("Localizable", "library.section.recentlyReviewed")
    }

    enum Subtitle {
      static let recentlyPlayed = L10n.tr("Localizable", "library.subtitle.recentlyPlayed")
      static let playtimeRecommendations = L10n.tr("Localizable", "library.subtitle.playtimeRecommendations")
    }

    enum Label {
      static let lastPlayed = L10n.tr("Localizable", "library.label.lastPlayed")
      static let playtime = L10n.tr("Localizable", "library.label.playtime")
    }

    enum Summary {
      static let totalPlay = L10n.tr("Localizable", "library.summary.totalPlay")
      static let averageRating = L10n.tr("Localizable", "library.summary.averageRating")
      static let gameCount = L10n.tr("Localizable", "library.summary.gameCount")
      static let wishlist = L10n.tr("Localizable", "library.summary.wishlist")
      static let reviewed = L10n.tr("Localizable", "library.summary.reviewed")
    }

    enum PrimaryTab {
      static let playing = L10n.tr("Localizable", "library.primaryTab.playing")
      static let wishlist = L10n.tr("Localizable", "library.primaryTab.wishlist")
      static let reviewed = L10n.tr("Localizable", "library.primaryTab.reviewed")
    }

    enum Filter {
      static let recent = L10n.tr("Localizable", "library.filter.recent")
      static let rating = L10n.tr("Localizable", "library.filter.rating")
      static let playtime = L10n.tr("Localizable", "library.filter.playtime")
    }

    enum Steam {
      enum Title {
        static let connected = L10n.tr("Localizable", "library.steam.title.connected")
        static let guide = L10n.tr("Localizable", "library.steam.title.guide")
      }

      enum Message {
        static let syncing = L10n.tr("Localizable", "library.steam.message.syncing")
        static let connected = L10n.tr("Localizable", "library.steam.message.connected")
        static let guide = L10n.tr("Localizable", "library.steam.message.guide")
      }

      enum Button {
        static let sync = L10n.tr("Localizable", "library.steam.button.sync")
        static let syncing = L10n.tr("Localizable", "library.steam.button.syncing")
        static let disconnect = L10n.tr("Localizable", "library.steam.button.disconnect")
        static let connect = L10n.tr("Localizable", "library.steam.button.connect")
      }

      enum Status {
        static let syncing = L10n.tr("Localizable", "library.steam.status.syncing")
        static let error = L10n.tr("Localizable", "library.steam.status.error")
        static let connected = L10n.tr("Localizable", "library.steam.status.connected")
        static let disconnected = L10n.tr("Localizable", "library.steam.status.disconnected")
      }

      enum LastSync {
        static let none = L10n.tr("Localizable", "library.steam.lastSync.none")
      }
    }

    enum Alert {
      static let removeFavoriteTitle = L10n.tr("Localizable", "library.alert.removeFavoriteTitle")

      static func removeFavoriteMessage(_ p1: String) -> String {
        L10n.tr("Localizable", "library.alert.removeFavoriteMessage", p1)
      }
    }

    enum Playtime {
      static func hours(_ p1: Int) -> String {
        L10n.tr("Localizable", "library.playtime.hours", p1)
      }
    }
  }

  enum Profile {
    enum Tab {
      static let title = L10n.tr("Localizable", "profile.tab.title")
    }

    enum Navigation {
      static let title = L10n.tr("Localizable", "profile.navigation.title")
    }

    enum Section {
      static let recentPlay = L10n.tr("Localizable", "profile.section.recentPlay")
      static let likedGames = L10n.tr("Localizable", "profile.section.likedGames")
      static let reviews = L10n.tr("Localizable", "profile.section.reviews")
      static let connectedAccounts = L10n.tr("Localizable", "profile.section.connectedAccounts")
      static let socialTaste = L10n.tr("Localizable", "profile.section.socialTaste")
    }

    enum Empty {
      static let noActivity = L10n.tr("Localizable", "profile.empty.noActivity")
      static let noRecentPlay = L10n.tr("Localizable", "profile.empty.noRecentPlay")
      static let noRecentPlayedGames = L10n.tr("Localizable", "profile.empty.noRecentPlayedGames")
      static let recentPlayLoading = L10n.tr("Localizable", "profile.empty.recentPlayLoading")
      static let recentPlayUnavailable = L10n.tr("Localizable", "profile.empty.recentPlayUnavailable")
    }

    enum RecentPlay {
      static func durationFormat(_ p1: String) -> String {
        L10n.tr("Localizable", "profile.recentPlay.durationFormat", p1)
      }
    }

    enum Action {
      static let steamFriends = L10n.tr("Localizable", "profile.action.steamFriends")
      static let friendsList = L10n.tr("Localizable", "profile.action.friendsList")
      static let friendRequests = L10n.tr("Localizable", "profile.action.friendRequests")
      static let findFriends = L10n.tr("Localizable", "profile.action.findFriends")
      static let logout = L10n.tr("Localizable", "profile.action.logout")
      static let deleteAccount = L10n.tr("Localizable", "profile.action.deleteAccount")
      static let terms = L10n.tr("Localizable", "profile.action.terms")
      static let privacyPolicy = L10n.tr("Localizable", "profile.action.privacyPolicy")
      static let communityGuidelines = L10n.tr("Localizable", "profile.action.communityGuidelines")
      static let contactSupport = L10n.tr("Localizable", "profile.action.contactSupport")
      static let socialPrivacy = L10n.tr("Localizable", "profile.action.socialPrivacy")
      static let notificationSettings = L10n.tr("Localizable", "profile.action.notificationSettings")
      static let unlinkSteam = L10n.tr("Localizable", "profile.action.unlinkSteam")
      static let photoLibrary = L10n.tr("Localizable", "profile.action.photoLibrary")
      static let removePhoto = L10n.tr("Localizable", "profile.action.removePhoto")
      static let changePhoto = L10n.tr("Localizable", "profile.action.changePhoto")
      static let addPhoto = L10n.tr("Localizable", "profile.action.addPhoto")
    }

    enum Account {
      static let connected = L10n.tr("Localizable", "profile.account.connected")
    }

    enum Social {
      static let friendManagement = L10n.tr("Localizable", "profile.social.friendManagement")
      static let friendActivity = L10n.tr("Localizable", "profile.social.friendActivity")
      static let tasteTags = L10n.tr("Localizable", "profile.social.tasteTags")
    }

    enum Stat {
      static let playedGames = L10n.tr("Localizable", "profile.stat.playedGames")
      static let writtenReviews = L10n.tr("Localizable", "profile.stat.writtenReviews")
      static let wishlistedGames = L10n.tr("Localizable", "profile.stat.wishlistedGames")
    }

    enum Meta {
      static func friendsConnected(_ p1: Int) -> String {
        L10n.tr("Localizable", "profile.meta.friendsConnected", p1)
      }
    }

    enum Activity {
      static let none = L10n.tr("Localizable", "profile.activity.none")

      static func newCount(_ p1: Int) -> String {
        L10n.tr("Localizable", "profile.activity.newCount", p1)
      }
    }

    enum Taste {
      static let reviewStoryFocused = L10n.tr("Localizable", "profile.taste.reviewStoryFocused")
      static let reviewWishlistBased = L10n.tr("Localizable", "profile.taste.reviewWishlistBased")
      static let playRecordBased = L10n.tr("Localizable", "profile.taste.playRecordBased")
      static let dataAccumulating = L10n.tr("Localizable", "profile.taste.dataAccumulating")
    }

    enum Description {
      static let growth = L10n.tr("Localizable", "profile.description.growth")
    }

    enum Settings {
      static let title = L10n.tr("Localizable", "profile.settings.title")
      static let account = L10n.tr("Localizable", "profile.settings.account")
      static let service = L10n.tr("Localizable", "profile.settings.service")
      static let support = L10n.tr("Localizable", "profile.settings.support")
      static let logoutMessage = L10n.tr("Localizable", "profile.settings.logoutMessage")
      static let deleteMessage = L10n.tr("Localizable", "profile.settings.deleteMessage")
    }

    enum Alert {
      static let steamUnlinkTitle = L10n.tr("Localizable", "profile.alert.steamUnlinkTitle")
      static let steamUnlinkMessage = L10n.tr("Localizable", "profile.alert.steamUnlinkMessage")
    }

    enum Privacy {
      static let friendsListTitle = L10n.tr("Localizable", "profile.privacy.friendsListTitle")
      static let recentPlayTitle = L10n.tr("Localizable", "profile.privacy.recentPlayTitle")
      static let likedGamesTitle = L10n.tr("Localizable", "profile.privacy.likedGamesTitle")
      static let reviewsTitle = L10n.tr("Localizable", "profile.privacy.reviewsTitle")
      static let friendsListSubtitle = L10n.tr("Localizable", "profile.privacy.friendsListSubtitle")
      static let recentPlaySubtitle = L10n.tr("Localizable", "profile.privacy.recentPlaySubtitle")
      static let likedGamesSubtitle = L10n.tr("Localizable", "profile.privacy.likedGamesSubtitle")
      static let reviewsSubtitle = L10n.tr("Localizable", "profile.privacy.reviewsSubtitle")
      static let loadFailed = L10n.tr("Localizable", "profile.privacy.loadFailed")
      static let saveFailed = L10n.tr("Localizable", "profile.privacy.saveFailed")
      static let importLoading = L10n.tr("Localizable", "profile.privacy.importLoading")
      static let importButton = L10n.tr("Localizable", "profile.privacy.importButton")
      static let importSuccess = L10n.tr("Localizable", "profile.privacy.importSuccess")
      static let importFailed = L10n.tr("Localizable", "profile.privacy.importFailed")
      static let importHelper = L10n.tr("Localizable", "profile.privacy.importHelper")
    }

    enum Edit {
      static let title = L10n.tr("Localizable", "profile.edit.title")
      static let subtitle = L10n.tr("Localizable", "profile.edit.subtitle")
      static let nicknameTitle = L10n.tr("Localizable", "profile.edit.nicknameTitle")
      static let nicknamePlaceholder = L10n.tr("Localizable", "profile.edit.nicknamePlaceholder")
      static let photoPending = L10n.tr("Localizable", "profile.edit.photoPending")
      static let badgeTitle = L10n.tr("Localizable", "profile.edit.badgeTitle")
      static let badgeHelper = L10n.tr("Localizable", "profile.edit.badgeHelper")
      static let imageLoadFailed = L10n.tr("Localizable", "profile.edit.imageLoadFailed")
      static let saveSuccess = L10n.tr("Localizable", "profile.edit.saveSuccess")
    }

    enum Count {
      static func likes(_ p1: Int) -> String {
        L10n.tr("Localizable", "profile.count.likes", p1)
      }
    }
  }

  enum Friend {
    enum Search {
      static let title = L10n.Profile.Action.findFriends
      static let placeholder = L10n.tr("Localizable", "friend.search.placeholder")
      static let prompt = L10n.tr("Localizable", "friend.search.prompt")
      static let loadFailed = L10n.tr("Localizable", "friend.search.loadFailed")
      static let requestFailed = L10n.tr("Localizable", "friend.search.requestFailed")
      static let alreadyFriends = L10n.tr("Localizable", "friend.search.status.alreadyFriends")
      static let requestSent = L10n.tr("Localizable", "friend.search.status.requestSent")
      static let receivedRequest = L10n.tr("Localizable", "friend.search.status.receivedRequest")

      static func recentPlay(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.search.recentPlay", p1)
      }
    }

    enum Action {
      static let add = L10n.tr("Localizable", "friend.action.add")
      static let requested = L10n.tr("Localizable", "friend.action.requested")
      static let friend = L10n.tr("Localizable", "friend.action.friend")
      static let alreadyFriend = L10n.tr("Localizable", "friend.action.alreadyFriend")
      static let receivedRequestExists = L10n.tr("Localizable", "friend.action.receivedRequestExists")
      static let accept = L10n.tr("Localizable", "friend.action.accept")
      static let decline = L10n.tr("Localizable", "friend.action.decline")
      static let cancel = L10n.tr("Localizable", "friend.action.cancel")
      static let viewProfile = L10n.tr("Localizable", "friend.action.viewProfile")
      static let remove = L10n.tr("Localizable", "friend.action.remove")
      static let block = L10n.tr("Localizable", "friend.action.block")
    }

    enum Requests {
      static let title = L10n.Profile.Action.friendRequests
      static let receivedTab = L10n.tr("Localizable", "friend.requests.receivedTab")
      static let sentTab = L10n.tr("Localizable", "friend.requests.sentTab")
      static let loadFailed = L10n.tr("Localizable", "friend.requests.loadFailed")
      static let actionFailed = L10n.tr("Localizable", "friend.requests.actionFailed")
      static let emptyReceived = L10n.tr("Localizable", "friend.requests.empty.received")
      static let emptySent = L10n.tr("Localizable", "friend.requests.empty.sent")
      static let subtitleReceived = L10n.tr("Localizable", "friend.requests.subtitle.received")
      static let subtitleSent = L10n.tr("Localizable", "friend.requests.subtitle.sent")
      static let requestLabel = L10n.tr("Localizable", "friend.requests.requestLabel")
    }

    enum List {
      static let title = L10n.Profile.Action.friendsList
      static let loadFailed = L10n.tr("Localizable", "friend.list.loadFailed")
      static let defaultSubtitle = L10n.tr("Localizable", "friend.list.defaultSubtitle")

      static func recentPlay(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.list.recentPlay", p1)
      }
    }

    enum Activity {
      static let feedTitle = L10n.Profile.Social.friendActivity
      static let feedSummary = L10n.tr("Localizable", "friend.activity.feedSummary")
      static let loadFailed = L10n.tr("Localizable", "friend.activity.loadFailed")
      static let empty = L10n.tr("Localizable", "friend.activity.empty")

      static func reviewCreated(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.reviewCreated", p1)
      }

      static func reviewUpdated(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.reviewUpdated", p1)
      }

      static func likedGameAdded(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.likedGameAdded", p1)
      }

      static func likedGameRemoved(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.likedGameRemoved", p1)
      }

      static func ratingChangedValue(_ p1: String, _ p2: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.ratingChangedValue", p1, p2)
      }

      static func ratingChanged(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.ratingChanged", p1)
      }

      static func playStatusPlaying(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.playStatusPlaying", p1)
      }

      static func playStatusCompleted(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.playStatusCompleted", p1)
      }

      static func playStatusWishlist(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.playStatusWishlist", p1)
      }

      static func playStatusChanged(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.playStatusChanged", p1)
      }

      static func recentlyPlayed(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.activity.headline.recentlyPlayed", p1)
      }

      enum Subheadline {
        static let playStatusUpdate = L10n.tr("Localizable", "friend.activity.subheadline.playStatusUpdate")
        static let completed = L10n.tr("Localizable", "friend.activity.subheadline.completed")
        static let wishlist = L10n.tr("Localizable", "friend.activity.subheadline.wishlist")
        static let dropped = L10n.tr("Localizable", "friend.activity.subheadline.dropped")
        static let newReview = L10n.tr("Localizable", "friend.activity.subheadline.newReview")
        static let reviewUpdated = L10n.tr("Localizable", "friend.activity.subheadline.reviewUpdated")
        static let likedAdded = L10n.tr("Localizable", "friend.activity.subheadline.likedAdded")
        static let likedRemoved = L10n.tr("Localizable", "friend.activity.subheadline.likedRemoved")
        static let ratingChanged = L10n.tr("Localizable", "friend.activity.subheadline.ratingChanged")
        static let playStatus = L10n.tr("Localizable", "friend.activity.subheadline.playStatus")
        static let playing = L10n.tr("Localizable", "friend.activity.subheadline.playing")
        static let recentPlay = L10n.tr("Localizable", "friend.activity.subheadline.recentPlay")
      }
    }

    enum Presence {
      static let online = L10n.tr("Localizable", "friend.presence.online")
      static let playing = L10n.tr("Localizable", "friend.presence.playing")
      static let recentActivity = L10n.tr("Localizable", "friend.presence.recentActivity")
      static let recentPlay = L10n.tr("Localizable", "friend.presence.recentPlay")

      static func playingGame(_ p1: String) -> String {
        L10n.tr("Localizable", "friend.presence.playingGame", p1)
      }
    }

    enum Steam {
      static let title = L10n.Profile.Action.steamFriends
      static let connectRequired = L10n.tr("Localizable", "friend.steam.connectRequired")
      static let loadFailed = L10n.tr("Localizable", "friend.steam.loadFailed")
      static let privateData = L10n.tr("Localizable", "friend.steam.private")
      static let unavailable = L10n.tr("Localizable", "friend.steam.unavailable")
      static let empty = L10n.tr("Localizable", "friend.steam.empty")
      static let subtitleLinked = L10n.tr("Localizable", "friend.steam.subtitle.linked")
      static let subtitleLinkedSteam = L10n.tr("Localizable", "friend.steam.subtitle.linkedSteam")
      static let subtitleUnlinked = L10n.tr("Localizable", "friend.steam.subtitle.unlinked")
    }

    enum Profile {
      static let title = L10n.tr("Localizable", "friend.profile.title")
      static let bioEmpty = L10n.tr("Localizable", "friend.profile.bioEmpty")
      static let sectionTaste = L10n.tr("Localizable", "friend.profile.section.taste")
      static let sectionSharedGames = L10n.tr("Localizable", "friend.profile.section.sharedGames")
      static let sectionCommonLikedGames = L10n.tr("Localizable", "friend.profile.section.commonLikedGames")
      static let sectionCommonInterestGames = L10n.tr("Localizable", "friend.profile.section.commonInterestGames")
      static let sectionCommonHighlyRatedGames = L10n.tr("Localizable", "friend.profile.section.commonHighlyRatedGames")
      static let sectionRecentlyPlayedGames = L10n.Library.Section.recentlyPlayedGames
      static let sectionLikedGames = L10n.Profile.Section.likedGames
      static let sectionReviews = L10n.Profile.Section.reviews
      static let sectionRecommendations = L10n.Library.Section.friendRecommendations
      static let errorRemoveFailed = L10n.tr("Localizable", "friend.profile.error.removeFailed")
      static let errorBlockFailed = L10n.tr("Localizable", "friend.profile.error.blockFailed")
      static let successRemoved = L10n.tr("Localizable", "friend.profile.success.removed")
      static let successBlocked = L10n.tr("Localizable", "friend.profile.success.blocked")
      static let loadingTaste = L10n.tr("Localizable", "friend.profile.loading.taste")
      static let emptyTaste = L10n.tr("Localizable", "friend.profile.empty.taste")
      static let tasteFallbackTitle = L10n.tr("Localizable", "friend.profile.taste.fallbackTitle")
      static let tasteFallbackSummary = L10n.tr("Localizable", "friend.profile.taste.fallbackSummary")
      static let loadingSharedGames = L10n.tr("Localizable", "friend.profile.loading.sharedGames")
      static let emptySharedGames = L10n.tr("Localizable", "friend.profile.empty.sharedGames")
      static let emptySharedGamesPrivate = L10n.tr("Localizable", "friend.profile.empty.sharedGamesPrivate")
      static let loadingCommonLikedGames = L10n.tr("Localizable", "friend.profile.loading.commonLikedGames")
      static let emptyCommonLikedGames = L10n.tr("Localizable", "friend.profile.empty.commonLikedGames")
      static let loadingCommonInterestGames = L10n.tr("Localizable", "friend.profile.loading.commonInterestGames")
      static let emptyCommonInterestGames = L10n.tr("Localizable", "friend.profile.empty.commonInterestGames")
      static let loadingCommonHighlyRatedGames = L10n.tr("Localizable", "friend.profile.loading.commonHighlyRatedGames")
      static let emptyCommonHighlyRatedGames = L10n.tr("Localizable", "friend.profile.empty.commonHighlyRatedGames")
      static let loadingRecentlyPlayedGames = L10n.tr("Localizable", "friend.profile.loading.recentlyPlayedGames")
      static let emptyRecentlyPlayedGames = L10n.tr("Localizable", "friend.profile.empty.recentlyPlayedGames")
      static let loadingLikedGames = L10n.tr("Localizable", "friend.profile.loading.likedGames")
      static let emptyLikedGames = L10n.tr("Localizable", "friend.profile.empty.likedGames")
      static let loadingReviews = L10n.tr("Localizable", "friend.profile.loading.reviews")
      static let emptyReviews = L10n.tr("Localizable", "friend.profile.empty.reviews")
      static let loadingRecommendations = L10n.tr("Localizable", "friend.profile.loading.recommendations")
      static let emptyRecommendations = L10n.tr("Localizable", "friend.profile.empty.recommendations")
      static let alertRemoveTitle = L10n.tr("Localizable", "friend.profile.alert.removeTitle")
      static let alertRemoveMessage = L10n.tr("Localizable", "friend.profile.alert.removeMessage")
      static let alertBlockTitle = L10n.tr("Localizable", "friend.profile.alert.blockTitle")
      static let alertBlockMessage = L10n.tr("Localizable", "friend.profile.alert.blockMessage")
    }

    enum Recommendation {
      static let similarFriendNoticed = L10n.tr("Localizable", "friend.recommendation.reason.similarFriendNoticed")
      static let similarFriendHighlyRated = L10n.tr("Localizable", "friend.recommendation.reason.similarFriendHighlyRated")
      static let sharedRecentPlay = L10n.tr("Localizable", "friend.recommendation.reason.sharedRecentPlay")
    }

    enum Fallback {
      static let unknownUser = L10n.tr("Localizable", "friend.fallback.unknownUser")
      static let unknownFriend = L10n.tr("Localizable", "friend.fallback.unknownFriend")
      static let game = L10n.tr("Localizable", "friend.fallback.game")
      static let gameInfo = L10n.tr("Localizable", "friend.fallback.gameInfo")
    }
  }

  enum Review {
    enum Label {
      static let rating = L10n.tr("Localizable", "review.label.rating")
      static let content = L10n.tr("Localizable", "review.label.content")
    }

    enum Placeholder {
      static let content = L10n.tr("Localizable", "review.placeholder.content")
    }

    enum Empty {
      static let noReviews = L10n.tr("Localizable", "review.empty.noReviews")
      static let firstReview = L10n.tr("Localizable", "review.empty.firstReview")
    }

    enum Prompt {
      static let rateGame = L10n.tr("Localizable", "review.prompt.rateGame")
      static let selectRating = L10n.tr("Localizable", "review.prompt.selectRating")
    }

    enum Count {
      static func characters(_ p1: Int, _ p2: Int) -> String {
        L10n.tr("Localizable", "review.count.characters", p1, p2)
      }
    }

    enum Validation {
      static let selectRating = L10n.tr("Localizable", "review.validation.selectRating")
      static let enterContent = L10n.tr("Localizable", "review.validation.enterContent")

      static func minLength(_ p1: Int) -> String {
        L10n.tr("Localizable", "review.validation.minLength", p1)
      }
    }

    enum Navigation {
      static let create = L10n.tr("Localizable", "review.navigation.create")
      static let edit = L10n.tr("Localizable", "review.navigation.edit")
    }

    enum Button {
      static let submit = L10n.tr("Localizable", "review.button.submit")
      static let save = L10n.tr("Localizable", "review.button.save")
      static let submitting = L10n.tr("Localizable", "review.button.submitting")
      static let saving = L10n.tr("Localizable", "review.button.saving")
      static let delete = L10n.tr("Localizable", "review.button.delete")
      static let deleting = L10n.tr("Localizable", "review.button.deleting")
    }

    enum Action {
      static let edit = L10n.tr("Localizable", "review.action.edit")
      static let delete = L10n.tr("Localizable", "review.action.delete")
      static let report = L10n.tr("Localizable", "review.action.report")
      static let block = L10n.tr("Localizable", "review.action.block")
    }

    enum Alert {
      static let deleteTitle = L10n.tr("Localizable", "review.alert.deleteTitle")
      static let deleteMessage = L10n.tr("Localizable", "review.alert.deleteMessage")
    }

    enum Report {
      static let selectReason = L10n.tr("Localizable", "review.report.selectReason")
      static let message = L10n.tr("Localizable", "review.report.message")
      static let otherTitle = L10n.tr("Localizable", "review.report.otherTitle")
      static let otherMessage = L10n.tr("Localizable", "review.report.otherMessage")
      static let otherPlaceholder = L10n.tr("Localizable", "review.report.otherPlaceholder")
      static let submit = L10n.tr("Localizable", "review.report.submit")
      static let reasonSpam = L10n.tr("Localizable", "review.report.reason.spam")
      static let reasonAbusive = L10n.tr("Localizable", "review.report.reason.abusive")
      static let reasonSexual = L10n.tr("Localizable", "review.report.reason.sexual")
      static let reasonMisinformation = L10n.tr("Localizable", "review.report.reason.misinformation")
      static let reasonCopyright = L10n.tr("Localizable", "review.report.reason.copyright")
      static let reasonOther = L10n.tr("Localizable", "review.report.reason.other")
    }

    enum Block {
      static let title = L10n.tr("Localizable", "review.block.title")
      static let message = L10n.tr("Localizable", "review.block.message")
    }

    enum Compose {
      static let create = L10n.tr("Localizable", "review.compose.create")
      static let edit = L10n.tr("Localizable", "review.compose.edit")
    }
  }

  enum Settings {
    static let title = L10n.tr("Localizable", "settings.title")

    enum Action {
      static let login = L10n.tr("Localizable", "settings.action.login")
      static let signUp = L10n.tr("Localizable", "settings.action.signUp")
      static let logout = L10n.tr("Localizable", "settings.action.logout")
    }
  }

  enum Empty {
    static let noFriends = L10n.tr("Localizable", "empty.noFriends")
    static let noFavorites = L10n.tr("Localizable", "empty.noFavorites")
    static let noRecentPlay = L10n.tr("Localizable", "empty.noRecentPlay")
  }

  enum Notifications {
    static let empty = L10n.tr("Localizable", "notifications.empty")
  }

  enum Translation {
    enum Banner {
      static let machineTranslated = L10n.tr("Localizable", "translation.banner.machineTranslated")
    }

    enum Action {
      static let showOriginal = L10n.tr("Localizable", "translation.action.showOriginal")
      static let showTranslated = L10n.tr("Localizable", "translation.action.showTranslated")
    }
  }
}

extension L10n {
  static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

private final class BundleToken {
  static let bundle: Bundle = {
    Bundle.main
  }()
}

// swiftlint:enable all
