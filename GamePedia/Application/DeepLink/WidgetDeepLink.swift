import Foundation

enum WidgetDeepLink: Equatable {
    case game(Int)
    case trending
    case login
    case reviewNew(Int)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "gamepedia" else {
            return nil
        }

        let host = url.host?.lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "game":
            guard let idComponent = pathComponents.first,
                  let gameID = Int(idComponent) else {
                return nil
            }
            self = .game(gameID)
        case "trending":
            self = .trending
        case "login":
            self = .login
        case "review":
            guard pathComponents.count == 2,
                  pathComponents.first?.lowercased() == "new",
                  let gameID = Int(pathComponents[1]) else {
                return nil
            }
            self = .reviewNew(gameID)
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .game(let gameID):
            return URL(string: "gamepedia://game/\(gameID)")!
        case .trending:
            return URL(string: "gamepedia://trending")!
        case .login:
            return URL(string: "gamepedia://login")!
        case .reviewNew(let gameID):
            return URL(string: "gamepedia://review/new/\(gameID)")!
        }
    }
}
