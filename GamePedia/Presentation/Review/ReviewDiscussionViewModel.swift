import Combine
import Foundation

final class ReviewDiscussionViewModel {
    private(set) var state: ReviewDiscussionState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ReviewDiscussionState) -> Void)?

    private let fetchGameReviewsUseCase: FetchGameReviewsUseCase
    private let fetchReviewCommentsUseCase: FetchReviewCommentsUseCase
    private let toggleReviewLikeUseCase: ToggleReviewLikeUseCase
    private let createReviewCommentUseCase: CreateReviewCommentUseCase
    private let updateReviewCommentUseCase: UpdateReviewCommentUseCase
    private let deleteReviewCommentUseCase: DeleteReviewCommentUseCase
    private let reactToReviewCommentUseCase: ReactToReviewCommentUseCase
    private let submitReportUseCase: SubmitReportUseCase
    private let moderationRepository: any ModerationRepository
    private let reviewSeed: Review?
    private var cancellables = Set<AnyCancellable>()

    init(
        gameId: Int,
        gameTitle: String?,
        reviewId: String,
        reviewSeed: Review? = nil,
        highlightCommentId: String? = nil,
        fetchGameReviewsUseCase: FetchGameReviewsUseCase = FetchGameReviewsUseCase(reviewRepository: DefaultReviewRepository()),
        toggleReviewLikeUseCase: ToggleReviewLikeUseCase = ToggleReviewLikeUseCase(reviewRepository: DefaultReviewRepository()),
        reviewCommentRepository: any ReviewCommentRepository = DefaultReviewCommentRepository(),
        moderationRepository: any ModerationRepository = DefaultModerationRepository()
    ) {
        self.state = ReviewDiscussionState(
            gameId: gameId,
            initialGameTitle: gameTitle,
            reviewId: reviewId,
            initialHighlightCommentId: highlightCommentId
        )
        self.reviewSeed = reviewSeed
        self.fetchGameReviewsUseCase = fetchGameReviewsUseCase
        self.toggleReviewLikeUseCase = toggleReviewLikeUseCase
        self.fetchReviewCommentsUseCase = FetchReviewCommentsUseCase(repository: reviewCommentRepository)
        self.createReviewCommentUseCase = CreateReviewCommentUseCase(repository: reviewCommentRepository)
        self.updateReviewCommentUseCase = UpdateReviewCommentUseCase(repository: reviewCommentRepository)
        self.deleteReviewCommentUseCase = DeleteReviewCommentUseCase(repository: reviewCommentRepository)
        self.reactToReviewCommentUseCase = ReactToReviewCommentUseCase(repository: reviewCommentRepository)
        self.moderationRepository = moderationRepository
        self.submitReportUseCase = SubmitReportUseCase(moderationRepository: moderationRepository)
        observeCommentSync()
        observeReviewLikeSync()
    }

    func send(_ intent: ReviewDiscussionIntent) {
        ReviewDiscussionTrace.log("[ReviewDiscussionVM] send \(intent.logDescription)")
        switch intent {
        case .viewDidLoad, .didTapRetry:
            load()
        case .didTapReviewLike(let reviewId):
            toggleReviewLike(reviewId: reviewId)
        case .didTapDiscussionArea:
            if case .comment = state.composerMode {
                break
            }
            apply(.setComposerModePreservingText(.comment))
        case .didTapReply(let commentId):
            guard let comment = state.comments.first(where: { $0.id == commentId }) else { return }
            apply(.setComposerMode(.reply(
                parentCommentId: comment.parentCommentId ?? comment.id,
                parentNickname: comment.author.nickname,
                isSelfReply: comment.isMine
            )))
        case .didTapEdit(let commentId):
            guard let comment = state.comments.first(where: { $0.id == commentId }) else { return }
            apply(.setComposerMode(.edit(commentId: commentId)))
            apply(.setComposerText(comment.content))
        case .didTapDelete(let commentId):
            deleteComment(commentId: commentId)
        case .didTapReport:
            break
        case .didTapLike(let commentId):
            toggleReaction(on: commentId, desiredReaction: .like)
        case .didTapDislike(let commentId):
            toggleReaction(on: commentId, desiredReaction: .dislike)
        case .didTapToggleReplies(let parentCommentId):
            var expanded = state.expandedParentCommentIds
            if expanded.contains(parentCommentId) {
                expanded.remove(parentCommentId)
            } else {
                expanded.insert(parentCommentId)
            }
            apply(.setExpandedParentCommentIds(expanded))
        case .didChangeSort(let sortOption):
            apply(.setSortOption(sortOption))
        case .didChangeComposerText(let text):
            apply(.setComposerText(text))
        case .didTapCancelComposerMode:
            apply(.setComposerModePreservingText(.comment))
        case .didTapSubmit:
            submitComposer()
        }
    }

    private func apply(_ mutation: ReviewDiscussionMutation) {
        let reducedState = ReviewDiscussionReducer.reduce(state, mutation)
        guard reducedState != state else { return }
        state = reducedState
    }

    private func load() {
        ReviewDiscussionTrace.log("[ReviewDiscussionVM] load reviewId=\(state.reviewId)")
        apply(.setLoading(true))
        apply(.setError(nil))

        Task {
            do {
                let review = try await resolveReview()
                let resolvedTitle = state.initialGameTitle ?? L10n.Common.Label.untitledGame
                await MainActor.run {
                    self.apply(.setReview(review, gameTitle: resolvedTitle))
                }
                try await refreshComments()
                await MainActor.run {
                    self.apply(.setLoading(false))
                }
            } catch {
                await MainActor.run {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.apply(.setError(message))
                }
            }
        }
    }

    private func resolveReview() async throws -> Review {
        if let reviewSeed, reviewSeed.id == state.reviewId {
            return reviewSeed
        }

        let feed = try await fetchGameReviewsUseCase.execute(gameId: String(state.gameId), sort: .latest)
        let visibleReviews = feed.reviews.filter {
            !moderationRepository.hiddenReviewIDs().contains($0.id) && !moderationRepository.blockedUserIDs().contains($0.author.id)
        }
        guard let review = visibleReviews.first(where: { $0.id == state.reviewId }) else {
            throw ReviewCommentError.reviewNotFound
        }
        return review
    }

    private func refreshComments() async throws {
        guard let context = state.discussionContext else { return }
        let comments = try await fetchReviewCommentsUseCase.execute(context: context)
        let expandedIds = expandedParentCommentIds(for: comments, current: state.expandedParentCommentIds)
        await MainActor.run {
            self.apply(.setComments(comments))
            self.apply(.setExpandedParentCommentIds(expandedIds))
        }
    }

    private func expandedParentCommentIds(for comments: [ReviewComment], current: Set<String>) -> Set<String> {
        var expandedIds = current
        if let highlightCommentId = state.highlightedCommentId,
           let highlightedComment = comments.first(where: { $0.id == highlightCommentId }),
           let parentId = highlightedComment.parentCommentId {
            expandedIds.insert(parentId)
        }
        return expandedIds
    }

    private func submitComposer() {
        guard let context = state.discussionContext else { return }
        let trimmedText = state.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        apply(.setSubmitting(true))

        Task {
            do {
                let createdOrUpdatedComment: ReviewComment
                switch state.composerMode {
                case .comment:
                    createdOrUpdatedComment = try await createReviewCommentUseCase.execute(
                        draft: ReviewCommentDraft(parentCommentId: nil, content: trimmedText),
                        context: context
                    )
                    await MainActor.run {
                        self.apply(.setInlineNotice(L10n.tr("Localizable", "review.comment.notice.created")))
                    }
                case .reply(let parentCommentId, _, _):
                    createdOrUpdatedComment = try await createReviewCommentUseCase.execute(
                        draft: ReviewCommentDraft(parentCommentId: parentCommentId, content: trimmedText),
                        context: context
                    )
                    await MainActor.run {
                        self.apply(.setInlineNotice(L10n.tr("Localizable", "review.comment.notice.replied")))
                    }
                case .edit(let commentId):
                    createdOrUpdatedComment = try await updateReviewCommentUseCase.execute(
                        commentId: commentId,
                        content: trimmedText,
                        context: context
                    )
                    await MainActor.run {
                        self.apply(.setInlineNotice(L10n.tr("Localizable", "review.comment.notice.updated")))
                    }
                }

                try await refreshComments()

                await MainActor.run {
                    var expanded = self.state.expandedParentCommentIds
                    if let parentId = createdOrUpdatedComment.parentCommentId {
                        expanded.insert(parentId)
                        self.apply(.setExpandedParentCommentIds(expanded))
                    }
                    self.apply(.setComposerMode(.comment))
                    self.apply(.setComposerText(""))
                    self.apply(.setSubmitting(false))
                    self.apply(.triggerHighlight(commentId: createdOrUpdatedComment.id))
                }
            } catch {
                await MainActor.run {
                    self.apply(.setSubmitting(false))
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.apply(.setInlineNotice(message))
                }
            }
        }
    }

    private func deleteComment(commentId: String) {
        guard let context = state.discussionContext else { return }
        Task {
            do {
                _ = try await deleteReviewCommentUseCase.execute(commentId: commentId, context: context)
                try await refreshComments()
                await MainActor.run {
                    self.apply(.setInlineNotice(L10n.tr("Localizable", "review.comment.notice.deleted")))
                }
            } catch {
                await MainActor.run {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.apply(.setInlineNotice(message))
                }
            }
        }
    }

    func report(commentId: String, reason: ReportReason, detail: String?) {
        guard let comment = state.comments.first(where: { $0.id == commentId }) else { return }
        Task {
            do {
                try await submitReportUseCase.execute(
                    request: ReportRequest(
                        targetType: .comment,
                        targetId: comment.id,
                        reportedUserId: comment.author.id,
                        reportedUserName: comment.author.nickname,
                        reason: reason,
                        detail: detail?.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
                await MainActor.run {
                    self.apply(.setInlineNotice(L10n.tr("Localizable", "review.comment.notice.reported")))
                }
            } catch {
                await MainActor.run {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.apply(.setInlineNotice(message))
                }
            }
        }
    }

    private func toggleReaction(on commentId: String, desiredReaction: ReviewCommentReaction) {
        guard let context = state.discussionContext,
              let comment = state.comments.first(where: { $0.id == commentId }) else { return }

        let nextReaction: ReviewCommentReaction? = comment.myReaction == desiredReaction ? nil : desiredReaction
        ReviewDiscussionTrace.log(
            "[ReviewDiscussionVM] toggleReaction commentId=\(commentId) desired=\(desiredReaction.rawValue) next=\(nextReaction?.rawValue ?? "none")"
        )
        let optimisticComment = optimisticallyUpdatedComment(comment, nextReaction: nextReaction)
        apply(.replaceComment(optimisticComment))
        apply(.setReactionLoading(commentId: commentId, isLoading: true))

        Task {
            do {
                let updatedComment = try await reactToReviewCommentUseCase.execute(
                    commentId: commentId,
                    reaction: nextReaction,
                    context: context
                )
                await MainActor.run {
                    self.apply(.replaceComment(updatedComment))
                    self.apply(.setReactionLoading(commentId: commentId, isLoading: false))
                }
            } catch {
                await MainActor.run {
                    self.apply(.replaceComment(comment))
                    self.apply(.setReactionLoading(commentId: commentId, isLoading: false))
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.apply(.setInlineNotice(message))
                }
            }
        }
    }

    private func toggleReviewLike(reviewId: String) {
        guard !state.reactingReviewIds.contains(reviewId),
              let originalReview = state.review,
              originalReview.id == reviewId else {
            return
        }

        let optimisticReview = originalReview.togglingLikeOptimistically()
        ReviewDiscussionTrace.log(
            "[ReviewDiscussionVM] toggleReviewLike reviewId=\(reviewId) nextLiked=\(optimisticReview.isLikedByCurrentUser) likeCount=\(optimisticReview.likeCount)"
        )
        apply(.replaceReview(optimisticReview))
        apply(.setReviewReactionLoading(reviewId: reviewId, isLoading: true))
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
                let resolvedReview = originalReview.updatingLikeState(
                    likeCount: result.likeCount,
                    isLikedByCurrentUser: result.isLikedByCurrentUser
                )
                await MainActor.run {
                    self.apply(.replaceReview(resolvedReview))
                    self.apply(.setReviewReactionLoading(reviewId: reviewId, isLoading: false))
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
                    self.apply(.replaceReview(originalReview))
                    self.apply(.setReviewReactionLoading(reviewId: reviewId, isLoading: false))
                    ReviewLikeSyncCenter.send(
                        ReviewLikeSyncEvent(
                            reviewId: originalReview.id,
                            gameId: originalReview.gameId,
                            likeCount: originalReview.likeCount,
                            isLikedByCurrentUser: originalReview.isLikedByCurrentUser
                        )
                    )
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.apply(.setInlineNotice(message))
                }
            }
        }
    }

    private func optimisticallyUpdatedComment(_ comment: ReviewComment, nextReaction: ReviewCommentReaction?) -> ReviewComment {
        var likeCount = comment.likeCount
        var dislikeCount = comment.dislikeCount

        switch comment.myReaction {
        case .like:
            likeCount = max(0, likeCount - 1)
        case .dislike:
            dislikeCount = max(0, dislikeCount - 1)
        case .none:
            break
        }

        switch nextReaction {
        case .like:
            likeCount += 1
        case .dislike:
            dislikeCount += 1
        case .none:
            break
        }

        return ReviewComment(
            id: comment.id,
            reviewId: comment.reviewId,
            gameId: comment.gameId,
            gameTitle: comment.gameTitle,
            reviewSnippet: comment.reviewSnippet,
            parentCommentId: comment.parentCommentId,
            depth: comment.depth,
            author: comment.author,
            content: comment.content,
            createdAt: comment.createdAt,
            updatedAt: comment.updatedAt,
            isMine: comment.isMine,
            isReviewAuthor: comment.isReviewAuthor,
            isDeleted: comment.isDeleted,
            isEdited: comment.isEdited,
            replyCount: comment.replyCount,
            likeCount: likeCount,
            dislikeCount: dislikeCount,
            myReaction: nextReaction
        )
    }

    private func observeCommentSync() {
        ReviewCommentSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, event.reviewId == self.state.reviewId else { return }

                switch event.action {
                case .created, .updated, .deleted:
                    Task {
                        try? await self.refreshComments()
                    }
                case .reacted:
                    guard let comment = event.comment else { return }
                    self.apply(.replaceComment(comment))
                }
            }
            .store(in: &cancellables)
    }

    private func observeReviewLikeSync() {
        ReviewLikeSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, event.reviewId == self.state.reviewId, let currentReview = self.state.review else { return }
                let updatedReview = currentReview.updatingLikeState(
                    likeCount: event.likeCount,
                    isLikedByCurrentUser: event.isLikedByCurrentUser
                )
                guard updatedReview != currentReview else { return }
                self.apply(.replaceReview(updatedReview))
            }
            .store(in: &cancellables)
    }
}

private extension ReviewDiscussionIntent {
    var logDescription: String {
        switch self {
        case .viewDidLoad:
            return "intent=viewDidLoad"
        case .didTapRetry:
            return "intent=didTapRetry"
        case .didTapReviewLike(let reviewId):
            return "intent=didTapReviewLike reviewId=\(reviewId)"
        case .didTapDiscussionArea:
            return "intent=didTapDiscussionArea"
        case .didTapReply(let commentId):
            return "intent=didTapReply commentId=\(commentId)"
        case .didTapEdit(let commentId):
            return "intent=didTapEdit commentId=\(commentId)"
        case .didTapDelete(let commentId):
            return "intent=didTapDelete commentId=\(commentId)"
        case .didTapReport(let commentId):
            return "intent=didTapReport commentId=\(commentId)"
        case .didTapLike(let commentId):
            return "intent=didTapLike commentId=\(commentId)"
        case .didTapDislike(let commentId):
            return "intent=didTapDislike commentId=\(commentId)"
        case .didTapToggleReplies(let parentCommentId):
            return "intent=didTapToggleReplies parentCommentId=\(parentCommentId)"
        case .didChangeSort(let sortOption):
            return "intent=didChangeSort sort=\(sortOption)"
        case .didChangeComposerText(let text):
            return "intent=didChangeComposerText length=\(text.count)"
        case .didTapCancelComposerMode:
            return "intent=didTapCancelComposerMode"
        case .didTapSubmit:
            return "intent=didTapSubmit"
        }
    }
}
