import Foundation

enum LibraryCuratorReducer {
    static func reduce(_ state: LibraryCuratorViewState, _ mutation: LibraryCuratorMutation) -> LibraryCuratorViewState {
        var state = state

        switch mutation {
        case .setQuery(let query):
            state.queryText = query
        case .setQueryFromUserInput(let query):
            state.queryText = query
            state.selectedPromptChipID = nil
        case .setMode(let mode):
            state.selectedMode = mode
            state.selectedPromptChipID = mode.promptChipID
        case .setPrompt(let mode):
            state.selectedMode = mode
            state.selectedPromptChipID = mode.promptChipID
            state.queryText = mode == .overview ? "" : mode.localizedTitle
        case .toggleTasteTag(let id):
            if state.selectedTasteTagIDs.contains(id) {
                state.selectedTasteTagIDs.remove(id)
            } else {
                state.selectedTasteTagIDs.insert(id)
            }
        case .toggleGenreTag(let id):
            if state.selectedGenreTagIDs.contains(id) {
                state.selectedGenreTagIDs.remove(id)
            } else {
                state.selectedGenreTagIDs.insert(id)
            }
        case .setLoading(let isLoading):
            state.isLoading = isLoading
        case .setLoaded(
            let result,
            let summaryTitle,
            let summaryBody,
            let summaryBullets,
            let tasteTags,
            let sections,
            let isFallback,
            let fallbackMessage,
            let emptyMessage,
            let generatedAtText
        ):
            state.summaryTitle = summaryTitle
            state.summaryBody = summaryBody
            state.summaryBullets = summaryBullets
            state.tasteTags = tasteTags
            state.sections = sections
            state.isFallback = isFallback
            state.fallbackMessage = fallbackMessage
            state.emptyMessage = emptyMessage
            state.errorMessage = nil
            state.isDailyLimitExceeded = false
            state.dailyLimitExceededMessage = nil
            state.currentResult = result
            state.lastSuccessfulResult = result
            state.generatedAtText = generatedAtText
            state.hasLoadedOnce = true
            state.isStale = false
        case .setErrorMessage(let message):
            state.errorMessage = message
            state.hasLoadedOnce = message != nil || state.hasLoadedOnce
        case .setDailyLimitExceeded(let message, let preserveResults):
            state.isDailyLimitExceeded = true
            state.dailyLimitExceededMessage = message
            if state.currentResult == nil, let lastSuccessfulResult = state.lastSuccessfulResult {
                state.currentResult = lastSuccessfulResult
            }
            state.errorMessage = nil
            state.emptyMessage = preserveResults ? state.emptyMessage : nil
            state.hasLoadedOnce = true
            state.isLoading = false
        case .setFavorite(let gameId, let isFavorite):
            state.sections = state.sections.map { section in
                LibraryCuratorSectionViewState(
                    id: section.id,
                    title: section.title,
                    description: section.description,
                    items: section.items.map { item in
                        guard item.gameId == gameId else { return item }
                        var updatedItem = item
                        updatedItem.isFavorite = isFavorite
                        return updatedItem
                    }
                )
            }
        case .setFavoriteUpdating(let gameId, let isUpdating):
            state.sections = state.sections.map { section in
                LibraryCuratorSectionViewState(
                    id: section.id,
                    title: section.title,
                    description: section.description,
                    items: section.items.map { item in
                        guard item.gameId == gameId else { return item }
                        var updatedItem = item
                        updatedItem.isFavoriteUpdating = isUpdating
                        return updatedItem
                    }
                )
            }
        case .setStale(let isStale):
            state.isStale = isStale
        }

        return state
    }
}
