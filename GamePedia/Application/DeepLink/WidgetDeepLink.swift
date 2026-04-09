import Foundation

enum WidgetDeepLink: Equatable {
    case game(Int)
    case trending
    case profile
    case login
    case review(String)
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
        case "profile":
            self = .profile
        case "login":
            self = .login
        case "review":
            if pathComponents.count == 2,
               pathComponents.first?.lowercased() == "new",
               let gameID = Int(pathComponents[1]) {
                self = .reviewNew(gameID)
                return
            }

            guard pathComponents.count == 1,
                  let reviewID = pathComponents.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                  reviewID.isEmpty == false else {
                return nil
            }
            self = .review(reviewID)
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
        case .profile:
            return URL(string: "gamepedia://profile")!
        case .login:
            return URL(string: "gamepedia://login")!
        case .review(let reviewID):
            return URL(string: "gamepedia://review/\(reviewID)")!
        case .reviewNew(let gameID):
            return URL(string: "gamepedia://review/new/\(gameID)")!
        }
    }
}
