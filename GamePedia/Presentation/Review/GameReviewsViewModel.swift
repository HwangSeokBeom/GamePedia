import Combine
import Foundation

final class GameReviewsViewModel {

    private(set) var state: GameReviewsState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((GameReviewsState) -> Void)?
    var onComposeRequested: ((Review?) -> Void)?
    var onReviewsChanged: (() -> Void)?

    private let fetchGameReviewsUseCase: FetchGameReviewsUseCase
    private let fetchReviewCommentCountsUseCase: FetchReviewCommentCountsUseCase
    private let toggleReviewLikeUseCase: ToggleReviewLikeUseCase
    private let deleteReviewUseCase: DeleteReviewUseCase
    private let submitReportUseCase: SubmitReportUseCase
    private let blockUserUseCase: BlockUserUseCase
    private let moderationRepository: any ModerationRepository
    private let reviewSortOption: ReviewSortOption
    private var cancellables = Set<AnyCancellable>()

    init(
        gameId: Int,
        gameTitle: String,
        reviewSortOption: ReviewSortOption = .latest,
        fetchGameReviewsUseCase: FetchGameReviewsUseCase = FetchGameReviewsUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        toggleReviewLikeUseCase: ToggleReviewLikeUseCase = ToggleReviewLikeUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        reviewCommentRepository: any ReviewCommentRepository = DefaultReviewCommentRepository(),
        deleteReviewUseCase: DeleteReviewUseCase = DeleteReviewUseCase(
            reviewRepository: DefaultReviewRepository()
        ),
        moderationRepository: any ModerationRepository = DefaultModerationRepository()
    ) {
        self.state = GameReviewsState(gameId: gameId, gameTitle: gameTitle)
        self.reviewSortOption = reviewSortOption
        self.fetchGameReviewsUseCase = fetchGameReviewsUseCase
        self.toggleReviewLikeUseCase = toggleReviewLikeUseCase
        self.fetchReviewCommentCountsUseCase = FetchReviewCommentCountsUseCase(repository: reviewCommentRepository)
        self.deleteReviewUseCase = deleteReviewUseCase
        self.moderationRepository = moderationRepository
        self.submitReportUseCase = SubmitReportUseCase(moderationRepository: moderationRepository)
        self.blockUserUseCase = BlockUserUseCase(moderationRepository: moderationRepository)
        observeCommentChanges()
        observeReviewLikeChanges()
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
                let visibleReviews = self.visibleReviews(from: reviewFeed.reviews)
                let mergedReviews = await self.mergedReviewsWithDiscussionCounts(
                    visibleReviews,
                    screen: "GameReviews.loadReviews"
                )
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.reviews = mergedReviews
                    self.state.reviewSummary = self.makeReviewSummary(from: mergedReviews)
                }
            } catch {
                await MainActor.run {
                    let reviewError = ReviewError.from(error: error)
                    self.state.isLoading = false
                    self.state.errorMessage = reviewError.errorDescription ?? L10n.tr("Localizable", "review.error.loadFailed")
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
        // The top-level compose action always creates a new review. Editing is only available from an explicit review action.
        onComposeRequested?(nil)
    }

    func didTapEdit(review: Review) {
        onComposeRequested?(review)
    }

    func toggleReviewLike(reviewId: String) {
        guard !state.reactingReviewIds.contains(reviewId),
              let originalReview = state.reviews.first(where: { $0.id == reviewId }) else {
            return
        }

        let optimisticReview = originalReview.togglingLikeOptimistically()
        state.reactingReviewIds.insert(reviewId)
        applyReviewUpdate(optimisticReview)
        ReviewLikeSyncCenter.send(
            ReviewLikeSyncEvent(
                reviewId: optimisticReview.id,
                gameId: optimisticReview.gameId,
                likeCount: optimisticReview.likeCount,
                isLikedByCurrentUser: optimisticReview.isLikedByCurrentUser
            )
        )

        Task {
            do {
                let result = try await toggleReviewLikeUseCase.execute(
                    reviewId: reviewId,
                    isCurrentlyLiked: originalReview.isLikedByCurrentUser
                )

                await MainActor.run {
                    self.state.reactingReviewIds.remove(reviewId)
                    self.applyReviewLikeState(
                        reviewId: reviewId,
                        likeCount: result.likeCount,
                        isLikedByCurrentUser: result.isLikedByCurrentUser
                    )
                    ReviewLikeSyncCenter.send(
                        ReviewLikeSyncEvent(
                            reviewId: reviewId,
                            gameId: originalReview.gameId,
                            likeCount: result.likeCount,
                            isLikedByCurrentUser: result.isLikedByCurrentUser
                        )
                    )
                }
            } catch {
                await MainActor.run {
                    let reviewError = ReviewError.from(error: error)
                    self.state.reactingReviewIds.remove(reviewId)
                    self.applyReviewUpdate(originalReview)
                    ReviewLikeSyncCenter.send(
                        ReviewLikeSyncEvent(
                            reviewId: originalReview.id,
                            gameId: originalReview.gameId,
                            likeCount: originalReview.likeCount,
                            isLikedByCurrentUser: originalReview.isLikedByCurrentUser
                        )
                    )
                    self.state.errorMessage = reviewError.errorDescription ?? L10n.tr("Localizable", "review.error.requestFailed")
                }
            }
        }
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
                    self.state.successMessage = L10n.tr("Localizable", "review.success.reported")
                    self.onReviewsChanged?()
                }
            } catch {
                await MainActor.run {
                    let moderationError = ModerationError.from(error: error)
                    self.state.reportingReviewId = nil
                    self.state.errorMessage = moderationError.errorDescription ?? L10n.tr("Localizable", "review.error.reportFailed")
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
                    self.state.successMessage = L10n.tr("Localizable", "review.success.blocked")
                    self.onReviewsChanged?()
                }
            } catch {
                await MainActor.run {
                    let moderationError = ModerationError.from(error: error)
                    self.state.blockingUserId = nil
                    self.state.errorMessage = moderationError.errorDescription ?? L10n.tr("Localizable", "review.error.blockFailed")
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
                    self.state.errorMessage = reviewError.errorDescription ?? L10n.tr("Localizable", "review.error.deleteFailed")
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

    private func mergedReviewsWithDiscussionCounts(_ reviews: [Review], screen: String) async -> [Review] {
        guard !reviews.isEmpty else { return reviews }

        do {
            let localCounts = try await fetchReviewCommentCountsUseCase.execute(reviewIds: reviews.map(\.id))
            return reviews.map { review in
                review.resolvingDiscussionCount(localCount: localCounts[review.id])
            }
        } catch {
            print("[ReviewDiscussionCount] mergeSkipped screen=\(screen) error=\(error.localizedDescription)")
            return reviews
        }
    }

    private func observeCommentChanges() {
        ReviewCommentSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                guard event.gameId == self.state.gameId || self.state.reviews.contains(where: { $0.id == event.reviewId }) else {
                    return
                }
                self.refreshVisibleReviewCommentCounts(reason: "commentSync")
            }
            .store(in: &cancellables)
    }

    private func refreshVisibleReviewCommentCounts(reason: String) {
        let currentReviews = state.reviews
        guard !currentReviews.isEmpty else { return }

        Task {
            let mergedReviews = await mergedReviewsWithDiscussionCounts(
                currentReviews,
                screen: "GameReviews.\(reason)"
            )

            await MainActor.run {
                guard self.state.reviews.map(\.id) == currentReviews.map(\.id) else { return }
                self.state.reviews = mergedReviews
                self.state.reviewSummary = self.makeReviewSummary(from: mergedReviews)
            }
        }
    }

    private func observeReviewLikeChanges() {
        ReviewLikeSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                guard let currentReview = self.state.reviews.first(where: { $0.id == event.reviewId }) else { return }
                let updatedReview = currentReview.updatingLikeState(
                    likeCount: event.likeCount,
                    isLikedByCurrentUser: event.isLikedByCurrentUser
                )
                guard updatedReview != currentReview else { return }
                self.state.reviews = self.state.reviews.map { review in
                    review.id == event.reviewId ? updatedReview : review
                }
            }
            .store(in: &cancellables)
    }

    private func applyReviewLikeState(
        reviewId: String,
        likeCount: Int,
        isLikedByCurrentUser: Bool
    ) {
        guard let currentReview = state.reviews.first(where: { $0.id == reviewId }) else { return }
        let updatedReview = currentReview.updatingLikeState(
            likeCount: likeCount,
            isLikedByCurrentUser: isLikedByCurrentUser
        )
        applyReviewUpdate(updatedReview)
    }

    private func applyReviewUpdate(_ updatedReview: Review) {
        let updatedReviews = state.reviews.map { review in
            review.id == updatedReview.id ? updatedReview : review
        }
        guard updatedReviews != state.reviews else { return }
        state.reviews = updatedReviews
    }
}
