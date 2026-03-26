import Foundation

// MARK: - ReviewReducer (pure function)

enum ReviewReducer {
    static func reduce(_ state: ReviewState, _ mutation: ReviewMutation) -> ReviewState {
        var state = state
        switch mutation {
        case .setRating(let rating):
            state.rating = rating
            state.submitEnabled = rating > 0 && !state.reviewText.isEmpty
        case .setText(let text):
            let cappedText = String(text.prefix(state.maxChars))
            state.reviewText = cappedText
            state.charCount = cappedText.count
            state.submitEnabled = state.rating > 0 && !cappedText.isEmpty
        case .setSpoiler(let isSpoiler):
            state.isSpoiler = isSpoiler
        case .setSubmitting(let isSubmitting):
            state.isSubmitting = isSubmitting
        case .setSubmitSuccess:
            state.isSubmitting = false
            state.didSubmitSuccessfully = true
        case .setError(let message):
            state.isSubmitting = false
            state.errorMessage = message
        }
        return state
    }
}
