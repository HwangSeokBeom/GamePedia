import Foundation

// MARK: - ReviewViewModel

final class ReviewViewModel {

    // MARK: State
    private(set) var state: ReviewState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ReviewState) -> Void)?

    // MARK: Dependencies
    private let apiClient: APIClient

    // MARK: Init
    init(
        gameId: Int,
        gameName: String,
        gameSubtitle: String = "",
        gameThumbnailURL: String,
        apiClient: APIClient = .shared
    ) {
        self.state = ReviewState(
            gameId: gameId,
            gameName: gameName,
            gameSubtitle: gameSubtitle,
            gameThumbnailURL: gameThumbnailURL
        )
        self.apiClient = apiClient
    }

    // MARK: - Intent Processing

    func send(_ intent: ReviewIntent) {
        switch intent {
        case .viewDidLoad:
            break
        case .ratingChanged(let rating):
            apply(.setRating(rating))
        case .textChanged(let text):
            apply(.setText(text))
        case .spoilerToggled(let isSpoiler):
            apply(.setSpoiler(isSpoiler))
        case .didTapSubmit:
            submitReview()
        }
    }

    // MARK: - Private

    private func apply(_ mutation: ReviewMutation) {
        state = ReviewReducer.reduce(state, mutation)
    }

    private func submitReview() {
        guard state.submitEnabled else { return }
        apply(.setSubmitting(true))

        let request = PostReviewRequestDTO(
            gameId: state.gameId,
            rating: Double(state.rating),
            body: state.reviewText,
            isSpoiler: state.isSpoiler
        )

        Task {
            do {
                _ = try await apiClient.request(
                    .postReview(gameId: state.gameId, body: request),
                    as: ReviewDTO.self
                )
                await MainActor.run {
                    self.apply(.setSubmitSuccess)
                }
            } catch {
                await MainActor.run {
                    self.apply(.setError(error.localizedDescription))
                }
            }
        }
    }
}
