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
    private let submitReportUseCase: SubmitReportUseCase
    private let blockUserUseCase: BlockUserUseCase
    private let moderationRepository: any ModerationRepository
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
        ),
        moderationRepository: any ModerationRepository = DefaultModerationRepository()
    ) {
        self.state = GameReviewsState(gameId: gameId, gameTitle: gameTitle)
        self.reviewSortOption = reviewSortOption
        self.fetchGameReviewsUseCase = fetchGameReviewsUseCase
        self.deleteReviewUseCase = deleteReviewUseCase
        self.moderationRepository = moderationRepository
        self.submitReportUseCase = SubmitReportUseCase(moderationRepository: moderationRepository)
        self.blockUserUseCase = BlockUserUseCase(moderationRepository: moderationRepository)
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
                    let visibleReviews = self.visibleReviews(from: reviewFeed.reviews)
                    self.state.isLoading = false
                    self.state.reviews = visibleReviews
                    self.state.reviewSummary = self.makeReviewSummary(from: visibleReviews)
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

    func report(review: Review, reason: ReportReason, detail: String?) {
        guard !state.isModerationActionInProgress else { return }

        state.errorMessage = nil
        state.successMessage = nil
        state.reportingReviewId = review.id

        Task {
            do {
                try await submitReportUseCase.execute(
                    request: ReportRequest(
                        targetType: .review,
                        targetId: review.id,
                        reportedUserId: review.author.id,
                        reportedUserName: review.authorName,
                        reason: reason,
                        detail: detail?.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )

                NotificationCenter.default.post(
                    name: .moderationDidChange,
                    object: nil,
                    userInfo: [
                        ModerationChangeUserInfoKey.targetType: ReportTargetType.review.rawValue,
                        ModerationChangeUserInfoKey.targetId: review.id,
                        ModerationChangeUserInfoKey.action: ModerationChangeAction.reported.rawValue
                    ]
                )

                await MainActor.run {
                    self.state.reportingReviewId = nil
                    self.state.reviews = self.state.reviews.filter { $0.id != review.id }
                    self.state.reviewSummary = self.makeReviewSummary(from: self.state.reviews)
                    self.state.successMessage = "신고가 접수되었습니다."
                    self.onReviewsChanged?()
                }
            } catch {
                await MainActor.run {
                    let moderationError = ModerationError.from(error: error)
                    self.state.reportingReviewId = nil
                    self.state.errorMessage = moderationError.errorDescription ?? "신고를 접수하지 못했습니다."
                }
            }
        }
    }

    func block(review: Review) {
        guard !state.isModerationActionInProgress else { return }

        state.errorMessage = nil
        state.successMessage = nil
        state.blockingUserId = review.author.id

        Task {
            do {
                try await blockUserUseCase.execute(
                    request: BlockUserRequest(
                        userId: review.author.id,
                        userName: review.authorName
                    )
                )

                NotificationCenter.default.post(
                    name: .moderationDidChange,
                    object: nil,
                    userInfo: [
                        ModerationChangeUserInfoKey.blockedUserId: review.author.id,
                        ModerationChangeUserInfoKey.action: ModerationChangeAction.blocked.rawValue
                    ]
                )

                await MainActor.run {
                    self.state.blockingUserId = nil
                    self.state.reviews = self.state.reviews.filter { $0.author.id != review.author.id }
                    self.state.reviewSummary = self.makeReviewSummary(from: self.state.reviews)
                    self.state.successMessage = "차단한 사용자의 콘텐츠는 더 이상 표시되지 않습니다."
                    self.onReviewsChanged?()
                }
            } catch {
                await MainActor.run {
                    let moderationError = ModerationError.from(error: error)
                    self.state.blockingUserId = nil
                    self.state.errorMessage = moderationError.errorDescription ?? "사용자를 차단하지 못했습니다."
                }
            }
        }
    }

    func clearSuccessMessage() {
        state.successMessage = nil
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

    private func visibleReviews(from reviews: [Review]) -> [Review] {
        let hiddenReviewIDs = moderationRepository.hiddenReviewIDs()
        let blockedUserIDs = moderationRepository.blockedUserIDs()

        return reviews.filter { review in
            !hiddenReviewIDs.contains(review.id) && !blockedUserIDs.contains(review.author.id)
        }
    }
}
