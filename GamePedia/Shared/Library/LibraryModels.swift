import Foundation

enum GameSource: String, Codable, Hashable {
    case steam
    case igdb
}

enum UserGameStatus: String, Codable, CaseIterable, Hashable {
    case wishlist
    case playing
    case completed
    case dropped
}

enum UserGameCollectionSortOption: String, CaseIterable {
    case latest
    case oldest
}

enum SteamLinkConnectionState: Hashable {
    case linked
    case notLinked
}

struct LibraryGameIdentifier: Hashable {
    let source: GameSource
    let sourceID: String
    let canonicalGameID: Int?

    var uniqueKey: String {
        "\(source.rawValue):\(sourceID)"
    }

    var detailGameID: Int? {
        canonicalGameID ?? (source == .igdb ? Int(sourceID) : nil)
    }
}

struct SteamLinkStatus: Hashable {
    let connectionState: SteamLinkConnectionState
    let steamID: String?
    let displayName: String?
    let profileURL: URL?

    var isLinked: Bool {
        connectionState == .linked
    }

    static let notLinked = SteamLinkStatus(
        connectionState: .notLinked,
        steamID: nil,
        displayName: nil,
        profileURL: nil
    )
}

struct LibraryGameSummary: Hashable {
    let identifier: LibraryGameIdentifier
    let title: String
    let translatedTitle: String?
    let coverImageURL: URL?
    let genre: String
    let platform: String
    let releaseYear: Int
    let rating: Double?
    let recentPlaytimeMinutes: Int?
    let recentPlaytimeText: String?
    let userStatus: UserGameStatus?

    var displayTitle: String { resolvedTitle }

    var resolvedTitle: String {
        Self.resolvedText(translatedTitle, fallback: title) ?? title
    }

    func replacingTranslatedTitle(_ translatedTitle: String?) -> LibraryGameSummary {
        LibraryGameSummary(
            identifier: identifier,
            title: title,
            translatedTitle: translatedTitle ?? self.translatedTitle,
            coverImageURL: coverImageURL,
            genre: genre,
            platform: platform,
            releaseYear: releaseYear,
            rating: rating,
            recentPlaytimeMinutes: recentPlaytimeMinutes,
            recentPlaytimeText: recentPlaytimeText,
            userStatus: userStatus
        )
    }
}

struct LibraryOverview: Hashable {
    let steamLinkStatus: SteamLinkStatus
    let recentlyPlayed: [LibraryGameSummary]
    let playing: [LibraryGameSummary]
}

struct LibraryGameStatusMutationResult: Hashable {
    let identifier: LibraryGameIdentifier
    let status: UserGameStatus
}

enum LibraryError: Error, LocalizedError, Equatable {
    case unauthorized
    case invalidGameIdentifier
    case invalidStatus
    case invalidResponse
    case network
    case server(code: String, message: String)
    case unknown(message: String)

    static func from(error: Error) -> LibraryError {
        if let libraryError = error as? LibraryError {
            return libraryError
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .configurationMissing(let message):
                return .server(code: "CONFIGURATION_MISSING", message: message)
            case .unauthorized:
                return .unauthorized
            case .serverError(_, let code, let message):
                let resolvedCode = code?.uppercased() ?? "UNKNOWN_ERROR"
                let resolvedMessage = message ?? "라이브러리 요청을 처리하지 못했습니다."
                switch resolvedCode {
                case "UNAUTHORIZED":
                    return .unauthorized
                case "INVALID_GAME_ID", "INVALID_SOURCE_ID":
                    return .invalidGameIdentifier
                case "INVALID_STATUS":
                    return .invalidStatus
                default:
                    return .server(code: resolvedCode, message: resolvedMessage)
                }
            case .invalidURL, .noData, .decodingFailed:
                return .invalidResponse
            case .unknown:
                return .network
            }
        }

        if error is URLError {
            return .network
        }

        return .unknown(message: error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "로그인이 필요합니다."
        case .invalidGameIdentifier:
            return "게임 식별 정보를 확인하지 못했습니다."
        case .invalidStatus:
            return "게임 상태를 처리하지 못했습니다."
        case .invalidResponse:
            return "서버 응답을 처리하지 못했습니다."
        case .network:
            return "네트워크 연결을 확인해주세요."
        case .server(_, let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}

private extension LibraryGameSummary {
    static func resolvedText(_ translated: String?, fallback: String?) -> String? {
        let normalizedTranslated = translated?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedTranslated, !normalizedTranslated.isEmpty {
            return normalizedTranslated
        }

        let normalizedFallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedFallback, !normalizedFallback.isEmpty {
            return normalizedFallback
        }

        return fallback
    }
}
