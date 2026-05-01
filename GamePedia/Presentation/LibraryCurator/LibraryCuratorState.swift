import Foundation

struct LibraryCuratorSummaryViewState: Equatable {
    let title: String?
    let body: String?
    let bullets: [String]
}

struct LibraryCuratorEmptyStatePresentation: Equatable {
    let title: String?
    let message: String
}

enum LibraryCuratorDailyLimitPresentation: Equatable {
    case none
    case banner(message: String)
    case empty(title: String, message: String)

    var logName: String {
        switch self {
        case .none:
            return "none"
        case .banner:
            return "banner"
        case .empty:
            return "empty"
        }
    }
}

enum LibraryCuratorAnalyzeButtonState: Equatable {
    case idle
    case loading
    case dailyLimitExceeded
    case disabled
    case retryableError
}

typealias LibraryCuratorAnalyzeButtonStyle = LibraryCuratorAnalyzeButtonState

struct LibraryCuratorViewState: Equatable {
    var selectedMode: LibraryCuratorMode = .overview
    var selectedPromptChipID: String? = LibraryCuratorMode.overview.promptChipID
    var selectedTasteTagIDs: Set<String> = []
    var selectedGenreTagIDs: Set<String> = []
    var queryText: String = ""
    var isLoading: Bool = false
    var summaryTitle: String? = nil
    var summaryBody: String? = nil
    var summaryBullets: [String] = []
    var tasteTags: [String] = []
    var sections: [LibraryCuratorSectionViewState] = []
    var isFallback: Bool = false
    var fallbackMessage: String? = nil
    var isDailyLimitExceeded: Bool = false
    var dailyLimitExceededMessage: String? = nil
    var currentResult: LibraryCuratorResult? = nil
    var lastSuccessfulResult: LibraryCuratorResult? = nil
    var emptyMessage: String? = nil
    var errorMessage: String? = nil
    var generatedAtText: String? = nil
    var hasLoadedOnce: Bool = false
    var isStale: Bool = false

    var selectedPrompt: String? {
        selectedPromptChipID
    }

    var inputText: String {
        queryText
    }

    var dailyLimitMessage: String? {
        dailyLimitExceededMessage
    }

    var canAnalyze: Bool {
        analyzeButtonState == .idle || analyzeButtonState == .retryableError
    }

    var showsEmptyState: Bool {
        hasLoadedOnce
            && !isLoading
            && !isDailyLimitExceeded
            && errorMessage == nil
            && visibleRecommendations.isEmpty
            && emptyState != nil
    }

    var shouldShowSummarySection: Bool {
        visibleSummary != nil
    }

    var shouldShowTasteProfileSection: Bool {
        !visibleTasteProfile.isEmpty
    }

    var shouldShowRecommendationSection: Bool {
        !visibleRecommendations.isEmpty && errorMessage == nil
    }

    var shouldShowEmptyState: Bool {
        showsEmptyState
    }

    var shouldShowDailyLimitBanner: Bool {
        if case .banner = dailyLimitPresentation {
            return true
        }
        return false
    }

    var shouldShowDailyLimitEmptyState: Bool {
        if case .empty = dailyLimitPresentation {
            return true
        }
        return false
    }

    var selectedTagsCount: Int {
        selectedTasteTagIDs.count + selectedGenreTagIDs.count
    }

    var hasDisplayableResult: Bool {
        visibleSummary != nil || !visibleTasteProfile.isEmpty || !visibleRecommendations.isEmpty
    }

    var visibleSummary: LibraryCuratorSummaryViewState? {
        let title = summaryTitle.nilIfBlank
        let body = summaryBody.nilIfBlank
        let bullets = summaryBullets.map(\.trimmedForDisplay).filter { !$0.isEmpty }
        guard title != nil || body != nil || !bullets.isEmpty else { return nil }
        return LibraryCuratorSummaryViewState(title: title, body: body, bullets: bullets)
    }

    var visibleTasteProfile: [String] {
        tasteTags.map(\.trimmedForDisplay).filter { !$0.isEmpty }
    }

    var visibleRecommendations: [LibraryCuratorSectionViewState] {
        sections.compactMap { section in
            let items = section.items.filter { !$0.title.trimmedForDisplay.isEmpty }
            guard !items.isEmpty else { return nil }
            return LibraryCuratorSectionViewState(
                id: section.id,
                title: section.title,
                description: section.description,
                items: items
            )
        }
    }

    var bannerMessage: String? {
        if case .banner(let message) = dailyLimitPresentation {
            return message
        }
        return fallbackMessage.nilIfBlank
    }

    var emptyState: LibraryCuratorEmptyStatePresentation? {
        if case .empty(let title, let message) = dailyLimitPresentation {
            return LibraryCuratorEmptyStatePresentation(title: title, message: message)
        }
        guard let message = emptyMessage.nilIfBlank else { return nil }
        return LibraryCuratorEmptyStatePresentation(
            title: L10n.tr("Localizable", "library_curator_empty_title"),
            message: message
        )
    }

    var dailyLimitPresentation: LibraryCuratorDailyLimitPresentation {
        guard isDailyLimitExceeded else { return .none }
        if hasDisplayableResult {
            return .banner(message: L10n.tr("Localizable", "library_curator_daily_limit_message"))
        }
        return .empty(
            title: L10n.tr("Localizable", "library_curator_daily_limit_empty_title"),
            message: L10n.tr("Localizable", "library_curator_daily_limit_empty_message")
        )
    }

    var analyzeButtonTitle: String {
        if isLoading {
            return L10n.tr("Localizable", "library_curator_analyzing_button")
        }
        if isDailyLimitExceeded {
            return L10n.tr("Localizable", "library_curator_daily_limit_button")
        }
        if errorMessage != nil {
            return L10n.tr("Localizable", "library_curator_retry_button")
        }
        return L10n.tr("Localizable", "library_curator_analyze_button")
    }

    var analyzeButtonIcon: String {
        isDailyLimitExceeded ? "lock.fill" : "sparkles"
    }

    var analyzeButtonState: LibraryCuratorAnalyzeButtonState {
        if isLoading {
            return .loading
        }
        if isDailyLimitExceeded {
            return .dailyLimitExceeded
        }
        if errorMessage != nil {
            return .retryableError
        }
        return .idle
    }

    var analyzeButtonStyle: LibraryCuratorAnalyzeButtonStyle {
        analyzeButtonState
    }
}

struct LibraryCuratorSectionViewState: Equatable {
    let id: String
    let title: String
    let description: String
    let items: [LibraryCuratorItemViewState]
}

struct LibraryCuratorItemViewState: Equatable {
    let gameId: String
    let title: String
    let coverUrl: URL?
    let subtitle: String
    let ratingText: String
    let reason: String
    let displayTags: [String]
    let confidenceText: String?
    var isFavorite: Bool
    let playtimeText: String?
    let userRatingText: String?
    var isFavoriteUpdating: Bool = false
}

extension LibraryCuratorMode {
    var promptChipID: String {
        "prompt:\(rawValue)"
    }
}

private extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let value = self?.trimmedForDisplay, !value.isEmpty else { return nil }
        return value
    }
}

private extension String {
    var trimmedForDisplay: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
