import Foundation

enum LibraryCuratorMode: String, CaseIterable {
    case overview
    case today
    case rediscover
    case shortSession = "short_session"
    case reviewInsight = "review_insight"

    var localizedTitle: String {
        switch self {
        case .overview:
            return L10n.tr("Localizable", "library_curator_mode_overview")
        case .today:
            return L10n.tr("Localizable", "library_curator_mode_today")
        case .rediscover:
            return L10n.tr("Localizable", "library_curator_mode_rediscover")
        case .shortSession:
            return L10n.tr("Localizable", "library_curator_mode_short_session")
        case .reviewInsight:
            return L10n.tr("Localizable", "library_curator_mode_review_insight")
        }
    }
}

enum LibraryCuratorCandidateScope: String {
    case owned
    case favorites
    case reviewed
    case mixed
}

struct LibraryCuratorRequest: Equatable {
    let query: String?
    let mode: LibraryCuratorMode
    let limit: Int
    let locale: String
    let candidateScope: LibraryCuratorCandidateScope
    let excludedGameIds: [String]
}

struct LibraryCuratorResult: Equatable {
    let mode: LibraryCuratorMode
    let source: String
    let summary: LibraryCuratorSummary
    let tasteProfile: LibraryCuratorTasteProfile
    let sections: [LibraryCuratorSection]
    let games: [LibraryCuratorGame]
    let meta: LibraryCuratorMeta

    var isFallback: Bool {
        source.lowercased() == "fallback"
    }
}

struct LibraryCuratorSummary: Equatable {
    let title: String
    let body: String
    let bullets: [String]
}

struct LibraryCuratorTasteProfile: Equatable {
    let topGenres: [String]
    let topThemes: [String]
    let preferredSession: String
    let playStyleTags: [String]
    let ratingStyle: String?
}

struct LibraryCuratorSection: Equatable {
    let id: String
    let title: String
    let description: String
    let items: [LibraryCuratorItem]
}

struct LibraryCuratorItem: Equatable {
    let gameId: String
    let reason: String
    let matchTags: [String]
    let confidence: Double
}

struct LibraryCuratorGame: Equatable {
    let gameId: String
    let title: String
    let coverURL: URL?
    let genres: [String]
    let platforms: [String]
    let rating: Double?
    let source: String?
    let playtimeMinutes: Int?
    let lastPlayedAt: String?
    let isFavorite: Bool
    let hasReview: Bool
    let userRating: Double?
}

struct LibraryCuratorMeta: Equatable {
    let candidateCount: Int
    let selectedCount: Int
    let fallbackReason: String?
    let generatedAt: String
    let locale: String
}
