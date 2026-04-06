import Foundation

final class ReviewDiscussionViewModel {
    private(set) var state: ReviewDiscussionState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ReviewDiscussionState) -> Void)?

    private let fetchGameReviewsUseCase: FetchGameReviewsUseCase
    private let fetchReviewCommentsUseCase: FetchReviewCommentsUseCase
    private let createReviewCommentUseCase: CreateReviewCommentUseCase
    private let updateReviewCommentUseCase: UpdateReviewCommentUseCase
    private let deleteReviewCommentUseCase: DeleteReviewCommentUseCase
    private let reactToReviewCommentUseCase: ReactToReviewCommentUseCase
    private let submitReportUseCase: SubmitReportUseCase
    private let moderationRepository: any ModerationRepository
    private let reviewSeed: Review?

    init(
        gameId: Int,
        gameTitle: String?,
        reviewId: String,
        reviewSeed: Review? = nil,
        highlightCommentId: String? = nil,
        fetchGameReviewsUseCase: FetchGameReviewsUseCase = FetchGameReviewsUseCase(reviewRepository: DefaultReviewRepository()),
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
        self.fetchReviewCommentsUseCase = FetchReviewCommentsUseCase(repository: reviewCommentRepository)
        self.createReviewCommentUseCase = CreateReviewCommentUseCase(repository: reviewCommentRepository)
        self.updateReviewCommentUseCase = UpdateReviewCommentUseCase(repository: reviewCommentRepository)
        self.deleteReviewCommentUseCase = DeleteReviewCommentUseCase(repository: reviewCommentRepository)
        self.reactToReviewCommentUseCase = ReactToReviewCommentUseCase(repository: reviewCommentRepository)
        self.moderationRepository = moderationRepository
        self.submitReportUseCase = SubmitReportUseCase(moderationRepository: moderationRepository)
    }

    func send(_ intent: ReviewDiscussionIntent) {
        switch intent {
        case .viewDidLoad, .didTapRetry:
            load()
        case .didTapReply(let commentId):
            guard let comment = state.comments.first(where: { $0.id == commentId }) else { return }
            apply(.setComposerMode(.reply(
                parentCommentId: comment.parentCommentId ?? comment.id,
                parentNickname: comment.author.nickname,
                isSelfReply: comment.author.id == comment.author.id && comment.isMine
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
        case .didChangeComposerText(let text):
            apply(.setComposerText(text))
        case .didTapCancelComposerMode:
            apply(.setComposerMode(.comment))
            apply(.setComposerText(""))
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
                    self.apply(.setReactionLoading(commentId: commentId, isLoading: false))
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.apply(.setInlineNotice(message))
                }
            }
        }
    }
}
