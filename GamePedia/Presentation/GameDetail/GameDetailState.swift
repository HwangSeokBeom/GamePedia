import Foundation

// MARK: - GameDetailState

struct GameDetailState {
    var isLoading: Bool = false
    var game: GameDetail? = nil
    var reviews: [Review] = []
    var isOwned: Bool = false
    var errorMessage: String? = nil
    var translatedTitle: String? = nil
    var translatedSummary: String? = nil
    var translatedStoryline: String? = nil

    var title: String { translatedTitle ?? game?.resolvedTitle ?? game?.title ?? "" }
    var summary: String { translatedSummary ?? game?.resolvedSummary ?? game?.summary ?? "" }
    var storyline: String { translatedStoryline ?? game?.resolvedStoryline ?? game?.storyline ?? "" }

    var resolvedTitle: String { title }
    var resolvedSummary: String { summary }
    var resolvedStoryline: String { storyline }
}
