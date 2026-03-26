import Foundation

final class GameReviewsViewModel {

    private(set) var state: GameReviewsState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((GameReviewsState) -> Void)?
    var onComposeRequested: ((Review?) -> Void)?
    var onReviewsChanged: (() -> Void)?

    private let fetchGameReviewsUseCase: FetchGameReviewsUseCase
    private let deleteReviewUseCase: DeleteReviewUseCase
    private let reviewSortOption: ReviewSortOption

    init(
        gameId: Int,
        gameTitle: String,
        reviewSortOption: ReviewSortOption = .latest,
        fetchGameReviewsUseCase: FetchGameReviewsUseCase = FetchGameReviewsUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        deleteReviewUseCase: DeleteReviewUseCase = DeleteReviewUseCase(
            reviewRepository: DefaultReviewRepository()
        )
    ) {
        self.state = GameReviewsState(gameId: gameId, gameTitle: gameTitle)
        self.reviewSortOption = reviewSortOption
        self.fetchGameReviewsUseCase = fetchGameReviewsUseCase
        self.deleteReviewUseCase = deleteReviewUseCase
    }

    func loadReviews() {
        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                let reviewFeed = try await fetchGameReviewsUseCase.execute(
                    gameId: String(state.gameId),
                    sort: reviewSortOption
                )
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.reviews = reviewFeed.reviews
                    self.state.reviewSummary = reviewFeed.summary
                }
            } catch {
                await MainActor.run {
                    let reviewError = ReviewError.from(error: error)
                    self.state.isLoading = false
                    self.state.errorMessage = reviewError.errorDescription ?? "리뷰를 불러오지 못했습니다."
                    self.state.reviews = []
                    self.state.reviewSummary = nil
                }
            }
        }
    }

    func reload() {
        loadReviews()
    }

    func didTapCompose() {
        onComposeRequested?(state.myReview)
    }

    func didTapEdit(review: Review) {
        onComposeRequested?(review)
    }

    func delete(review: Review) {
        guard state.deletingReviewId == nil else { return }
        state.deletingReviewId = review.id

        Task {
            do {
                _ = try await deleteReviewUseCase.execute(reviewId: review.id)
                NotificationCenter.default.post(
                    name: .reviewDidChange,
                    object: nil,
                    userInfo: [
                        ReviewChangeUserInfoKey.gameId: String(state.gameId),
                        ReviewChangeUserInfoKey.reviewId: review.id,
                        ReviewChangeUserInfoKey.action: ReviewChangeAction.deleted.rawValue
                    ]
                )
                await MainActor.run {
                    let remainingReviews = self.state.reviews.filter { $0.id != review.id }
                    self.state.deletingReviewId = nil
                    self.state.reviews = remainingReviews
                    self.state.reviewSummary = self.makeReviewSummary(from: remainingReviews)
                    self.onReviewsChanged?()
                    self.loadReviews()
                }
            } catch {
                await MainActor.run {
                    let reviewError = ReviewError.from(error: error)
                    self.state.deletingReviewId = nil
                    self.state.errorMessage = reviewError.errorDescription ?? "리뷰를 삭제하지 못했습니다."
                }
            }
        }
    }

    private func makeReviewSummary(from reviews: [Review]) -> ReviewSummary {
        guard !reviews.isEmpty else {
            return ReviewSummary(reviewCount: 0, averageRating: nil)
        }

        let averageRating = reviews.reduce(0.0) { $0 + $1.rating } / Double(reviews.count)
        let roundedAverageRating = (averageRating * 10).rounded() / 10
        return ReviewSummary(
            reviewCount: reviews.count,
            averageRating: roundedAverageRating
        )
    }
}
