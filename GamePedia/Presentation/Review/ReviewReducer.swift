import Foundation

// MARK: - ReviewReducer (pure function)

enum ReviewReducer {
    static func reduce(_ state: ReviewState, _ mutation: ReviewMutation) -> ReviewState {
        var state = state
        switch mutation {
        case .setRating(let rating):
            state.rating = rating
            state.errorMessage = nil
            state.submitEnabled = canSubmit(state)
        case .setText(let text):
            let cappedText = String(text.prefix(state.maxChars))
            state.reviewText = cappedText
            state.charCount = cappedText.count
            state.errorMessage = nil
            state.submitEnabled = canSubmit(state)
        case .setSpoiler(let isSpoiler):
            state.isSpoiler = isSpoiler
            state.errorMessage = nil
        case .setSubmitting(let isSubmitting):
            state.isSubmitting = isSubmitting
            state.errorMessage = nil
            state.submitEnabled = !isSubmitting && canSubmit(state)
        case .setSubmitSuccess:
            state.isSubmitting = false
            state.didSubmitSuccessfully = true
            state.submitEnabled = false
            state.errorMessage = nil
        case .setError(let message):
            state.isSubmitting = false
            state.errorMessage = message
            state.submitEnabled = canSubmit(state)
        }
        return state
    }

    private static func canSubmit(_ state: ReviewState) -> Bool {
        state.hasSelectedRating && state.hasValidReviewText
    }
}
