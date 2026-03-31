import Foundation

struct HomeContentFilter: Hashable {
    var platform: HomePlatformFilter
    var category: HomeCategoryFilter
    var gameMode: HomeGameModeFilter

    static let `default` = HomeContentFilter(
        platform: .all,
        category: .all,
        gameMode: .all
    )

    var hasActiveSelection: Bool {
        platform != .all || category != .all || gameMode != .all
    }
}

enum HomePlatformFilter: String, CaseIterable, Hashable {
    case all
    case steam
    case playStation
    case nintendo
    case xbox
    case mobile

    var title: String {
        switch self {
        case .all:
            return "전체 플랫폼"
        case .steam:
            return "Steam"
        case .playStation:
            return "PlayStation"
        case .nintendo:
            return "Nintendo"
        case .xbox:
            return "Xbox"
        case .mobile:
            return "Mobile"
        }
    }

    var queryValue: String? {
        switch self {
        case .all:
            return nil
        case .steam:
            return "steam"
        case .playStation:
            return "playstation"
        case .nintendo:
            return "nintendo"
        case .xbox:
            return "xbox"
        case .mobile:
            return "mobile"
        }
    }
}

enum HomeCategoryFilter: String, CaseIterable, Hashable {
    case all
    case action
    case rpg
    case strategy
    case simulation
    case sports
    case adventure
    case indie
    case horror
    case puzzle

    var title: String {
        switch self {
        case .all:
            return "전체 카테고리"
        case .action:
            return "액션"
        case .rpg:
            return "RPG"
        case .strategy:
            return "전략"
        case .simulation:
            return "시뮬레이션"
        case .sports:
            return "스포츠"
        case .adventure:
            return "어드벤처"
        case .indie:
            return "인디"
        case .horror:
            return "공포"
        case .puzzle:
            return "퍼즐"
        }
    }

    var queryValue: String? {
        switch self {
        case .all:
            return nil
        case .action:
            return "action"
        case .rpg:
            return "rpg"
        case .strategy:
            return "strategy"
        case .simulation:
            return "simulation"
        case .sports:
            return "sports"
        case .adventure:
            return "adventure"
        case .indie:
            return "indie"
        case .horror:
            return "horror"
        case .puzzle:
            return "puzzle"
        }
    }
}

enum HomeGameModeFilter: String, CaseIterable, Hashable {
    case all
    case singlePlayer
    case multiPlayer
    case coop
    case pvp

    var title: String {
        switch self {
        case .all:
            return "전체 모드"
        case .singlePlayer:
            return "싱글 플레이"
        case .multiPlayer:
            return "멀티 플레이"
        case .coop:
            return "협동 플레이"
        case .pvp:
            return "PvP"
        }
    }

    var queryValue: String? {
        switch self {
        case .all:
            return nil
        case .singlePlayer:
            return "singleplayer"
        case .multiPlayer:
            return "multiplayer"
        case .coop:
            return "coop"
        case .pvp:
            return "pvp"
        }
    }
}
