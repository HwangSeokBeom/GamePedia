import Foundation

// MARK: - ReviewViewModel

final class ReviewViewModel {

    // MARK: State
    private(set) var state: ReviewState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ReviewState) -> Void)?

    // MARK: Dependencies
    private let createReviewUseCase: CreateReviewUseCase
    private let updateReviewUseCase: UpdateReviewUseCase
    private let deleteReviewUseCase: DeleteReviewUseCase

    // MARK: Init
    init(
        gameId: Int,
        gameName: String,
        gameSubtitle: String = "",
        gameThumbnailURL: String,
        existingReview: Review? = nil,
        createReviewUseCase: CreateReviewUseCase = CreateReviewUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        updateReviewUseCase: UpdateReviewUseCase = UpdateReviewUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        deleteReviewUseCase: DeleteReviewUseCase = DeleteReviewUseCase(
            reviewRepository: DefaultReviewRepository()
        )
    ) {
        self.state = ReviewState(
            gameId: gameId,
            gameName: gameName,
            gameSubtitle: gameSubtitle,
            gameThumbnailURL: gameThumbnailURL,
            existingReview: existingReview
        )
        self.createReviewUseCase = createReviewUseCase
        self.updateReviewUseCase = updateReviewUseCase
        self.deleteReviewUseCase = deleteReviewUseCase
    }

    // MARK: - Intent Processing

    func send(_ intent: ReviewIntent) {
        switch intent {
        case .viewDidLoad:
            break
        case .ratingChanged(let rating):
            print("[ReviewSubmit] ratingChanged rating=\(rating)")
            apply(.setRating(rating))
        case .textChanged(let text):
            print("[ReviewSubmit] textChanged rawCount=\(text.count) trimmedCount=\(text.trimmingCharacters(in: .whitespacesAndNewlines).count)")
            apply(.setText(text))
        case .didTapSubmit:
            print("[ReviewSubmit] didTapSubmit received by ViewModel")
            submitReview()
        case .didTapDelete:
            print("[ReviewDelete] didTapDelete received by ViewModel")
            deleteReview()
        }
    }

    // MARK: - Private

    private func apply(_ mutation: ReviewMutation) {
        state = ReviewReducer.reduce(state, mutation)
    }

    private func submitReview() {
        guard state.submitEnabled, !state.isSubmitting else {
            print("[ReviewSubmit] validationBlocked submitEnabled=\(state.submitEnabled) isSubmitting=\(state.isSubmitting) hasSelectedRating=\(state.hasSelectedRating) trimmedCount=\(state.trimmedReviewText.count) message=\(state.validationMessage ?? "nil")")
            if let validationMessage = state.validationMessage {
                apply(.setError(validationMessage))
            }
            return
        }
        print("[ReviewSubmit] validationPassed mode=\(state.isEditing ? "edit" : "create") gameId=\(state.gameId) reviewId=\(state.reviewId ?? "nil") rating=\(state.rating) trimmedCount=\(state.trimmedReviewText.count)")
        apply(.setSubmitting(true))

        Task {
            do {
                if let reviewId = state.reviewId {
                    print("[ReviewSubmit] calling updateReviewUseCase reviewId=\(reviewId)")
                    _ = try await updateReviewUseCase.execute(
                        reviewId: reviewId,
                        rating: Double(state.rating),
                        content: state.trimmedReviewText
                    )
                    NotificationCenter.default.post(
                        name: .reviewDidChange,
                        object: nil,
                        userInfo: [
                            ReviewChangeUserInfoKey.gameId: String(state.gameId),
                            ReviewChangeUserInfoKey.reviewId: reviewId,
                            ReviewChangeUserInfoKey.action: ReviewChangeAction.updated.rawValue
                        ]
                    )
                } else {
                    print("[ReviewSubmit] calling createReviewUseCase gameId=\(state.gameId)")
                    let createdReview = try await createReviewUseCase.execute(
                        gameId: String(state.gameId),
                        rating: Double(state.rating),
                        content: state.trimmedReviewText
                    )
                    NotificationCenter.default.post(
                        name: .reviewDidChange,
                        object: nil,
                        userInfo: [
                            ReviewChangeUserInfoKey.gameId: String(state.gameId),
                            ReviewChangeUserInfoKey.reviewId: createdReview.id,
                            ReviewChangeUserInfoKey.action: ReviewChangeAction.created.rawValue
                        ]
                    )
                }
                await MainActor.run {
                    print("[ReviewSubmit] submitSuccess")
                    self.apply(.setSubmitSuccess)
                }
            } catch {
                await MainActor.run {
                    let reviewError = ReviewError.from(error: error)
                    print("[ReviewSubmit] submitFailure error=\(reviewError.localizedDescription)")
                    self.apply(.setError(reviewError.errorDescription ?? "리뷰를 저장하지 못했습니다."))
                }
            }
        }
    }

    private func deleteReview() {
        guard let reviewId = state.reviewId, !state.isProcessing else { return }
        print("[ReviewDelete] deleteReview start reviewId=\(reviewId)")
        apply(.setDeleting(true))

        Task {
            do {
                _ = try await deleteReviewUseCase.execute(reviewId: reviewId)
                NotificationCenter.default.post(
                    name: .reviewDidChange,
                    object: nil,
                    userInfo: [
                        ReviewChangeUserInfoKey.gameId: String(state.gameId),
                        ReviewChangeUserInfoKey.reviewId: reviewId,
                        ReviewChangeUserInfoKey.action: ReviewChangeAction.deleted.rawValue
                    ]
                )
                await MainActor.run {
                    print("[ReviewDelete] deleteSuccess")
                    self.apply(.setDeleteSuccess)
                }
            } catch {
                await MainActor.run {
                    let reviewError = ReviewError.from(error: error)
                    print("[ReviewDelete] deleteFailure error=\(reviewError.localizedDescription)")
                    self.apply(.setError(reviewError.errorDescription ?? "리뷰를 삭제하지 못했습니다."))
                }
            }
        }
    }
}
