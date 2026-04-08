import XCTest
@testable import GamePedia

@MainActor
final class ReviewDiscussionInteractionTests: XCTestCase {
    override func tearDown() {
        ReviewDiscussionTrace.sink = nil
        InMemoryUserSessionStore.shared.clear()
        super.tearDown()
    }

    func testReviewDiscussionViewController_requiresExplicitReplyActionsAndDismissesOnContentTaps() async throws {
        let repository = MockReviewCommentRepository(
            comments: [
                makeComment(id: "root-comment", parentCommentId: nil, depth: 0, likeCount: 0, myReaction: nil),
                makeComment(id: "reply-comment", parentCommentId: "root-comment", depth: 1, likeCount: 1, myReaction: nil)
            ]
        )
        let reviewRepository = MockReviewRepository()
        let viewModel = makeViewModel(
            reviewCommentRepository: repository,
            reviewRepository: reviewRepository
        )
        let viewController = ReviewDiscussionViewController(
            rootView: ReviewDiscussionRootView(),
            viewModel: viewModel
        )
        let navigationController = UINavigationController(rootViewController: viewController)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigationController

        window.makeKeyAndVisible()
        viewController.loadViewIfNeeded()

        await waitUntil {
            viewController.rootView.tableView.numberOfSections == 3 &&
            viewController.rootView.tableView.numberOfRows(inSection: 2) == 2
        }

        viewController.view.layoutIfNeeded()
        viewController.rootView.tableView.layoutIfNeeded()

        let reviewHeaderIndexPath = IndexPath(row: 0, section: 0)
        let discussionHeaderIndexPath = IndexPath(row: 0, section: 1)
        let rootCommentIndexPath = IndexPath(row: 0, section: 2)
        let replyCommentIndexPath = IndexPath(row: 1, section: 2)

        viewController.rootView.tableView.scrollToRow(at: rootCommentIndexPath, at: .middle, animated: false)
        viewController.rootView.tableView.layoutIfNeeded()
        await waitUntil {
            guard let cell = viewController.rootView.tableView.cellForRow(at: rootCommentIndexPath) as? ReviewCommentCell else {
                return false
            }
            return self.findButton(in: cell.contentView, accessibilityIdentifier: "reviewComment.replyButton") != nil
        }
        guard let rootCell = viewController.rootView.tableView.cellForRow(at: rootCommentIndexPath) as? ReviewCommentCell,
              let rootReplyButton = findButton(in: rootCell.contentView, accessibilityIdentifier: "reviewComment.replyButton"),
              let rootLikeButton = findButton(in: rootCell.contentView, accessibilityIdentifier: "reviewComment.likeButton"),
              let rootMoreButton = findButton(in: rootCell.contentView, accessibilityIdentifier: "reviewComment.moreButton") else {
            return XCTFail("Root comment action buttons not found")
        }
        rootReplyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(
            viewModel.state.composerMode,
            makeReplyMode(
                targetCommentId: "root-comment",
                parentCommentId: "root-comment",
                nickname: "작성자-root-comment",
                previewText: "댓글-root-comment",
                isSelfReply: false
            )
        )

        rootLikeButton.sendActions(for: .touchUpInside)
        await waitUntil {
            return repository.reactCallCommentIds.contains("root-comment")
        }
        XCTAssertEqual(
            viewModel.state.composerMode,
            makeReplyMode(
                targetCommentId: "root-comment",
                parentCommentId: "root-comment",
                nickname: "작성자-root-comment",
                previewText: "댓글-root-comment",
                isSelfReply: false
            )
        )

        viewController.tableView(viewController.rootView.tableView, didSelectRowAt: replyCommentIndexPath)
        XCTAssertEqual(viewModel.state.composerMode, .comment)

        rootMoreButton.sendActions(for: .touchUpInside)
        await waitUntil(timeout: 3) {
            viewController.presentedViewController is ReviewCommentActionSheetViewController
        }
        guard let actionSheet = viewController.presentedViewController as? ReviewCommentActionSheetViewController else {
            return XCTFail("Comment action sheet not presented")
        }
        actionSheet.loadViewIfNeeded()
        guard let sheetReplyButton = findButton(
            in: actionSheet.view,
            accessibilityLabel: L10n.tr("Localizable", "review.comment.action.reply")
        ) else {
            return XCTFail("Action sheet reply button not found")
        }
        sheetReplyButton.sendActions(for: .touchUpInside)
        await waitUntil(timeout: 3) {
            if case .reply(let context) = viewModel.state.composerMode {
                return context.parentCommentId == "root-comment"
                    && context.targetCommentId == "root-comment"
                    && context.targetNickname == "작성자-root-comment"
                    && context.targetPreviewText == "댓글-root-comment"
                    && context.isSelfReply == false
            }
            return false
        }
        await waitUntil(timeout: 3) {
            viewController.presentedViewController == nil
        }

        viewController.tableView(viewController.rootView.tableView, didSelectRowAt: reviewHeaderIndexPath)
        XCTAssertEqual(viewModel.state.composerMode, .comment)

        rootReplyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(
            viewModel.state.composerMode,
            makeReplyMode(
                targetCommentId: "root-comment",
                parentCommentId: "root-comment",
                nickname: "작성자-root-comment",
                previewText: "댓글-root-comment",
                isSelfReply: false
            )
        )

        viewController.rootView.tableView.scrollToRow(at: discussionHeaderIndexPath, at: .middle, animated: false)
        viewController.rootView.tableView.layoutIfNeeded()
        await waitUntil {
            viewController.rootView.tableView.cellForRow(at: discussionHeaderIndexPath) is ReviewDiscussionSectionHeaderCell
        }
        guard let discussionHeaderCell = viewController.rootView.tableView.cellForRow(at: discussionHeaderIndexPath) as? ReviewDiscussionSectionHeaderCell,
              let sortButton = findButton(in: discussionHeaderCell.contentView, accessibilityIdentifier: "reviewDiscussion.sortButton") else {
            return XCTFail("Discussion header sort button not found")
        }
        sortButton.sendActions(for: .touchDown)
        XCTAssertEqual(viewModel.state.composerMode, .comment)

        rootReplyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(
            viewModel.state.composerMode,
            makeReplyMode(
                targetCommentId: "root-comment",
                parentCommentId: "root-comment",
                nickname: "작성자-root-comment",
                previewText: "댓글-root-comment",
                isSelfReply: false
            )
        )
        viewController.debugHandleNavigationBarTap()
        XCTAssertEqual(viewModel.state.composerMode, .comment)

        let blankAreaY = min(
            viewController.rootView.tableView.bounds.height - 10,
            viewController.rootView.tableView.contentSize.height + 20
        )
        rootReplyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(
            viewModel.state.composerMode,
            makeReplyMode(
                targetCommentId: "root-comment",
                parentCommentId: "root-comment",
                nickname: "작성자-root-comment",
                previewText: "댓글-root-comment",
                isSelfReply: false
            )
        )
        viewController.debugHandleTableTap(
            at: CGPoint(x: viewController.rootView.tableView.bounds.midX, y: blankAreaY)
        )
        XCTAssertEqual(viewModel.state.composerMode, .comment)
    }

    func testReviewDiscussionReviewLike_optimisticUpdateAndRollback() async throws {
        let reviewRepository = MockReviewRepository(
            likeDelayNanoseconds: 50_000_000,
            likeResult: .success(
                ReviewLikeMutationResult(
                    reviewId: "review-1",
                    likeCount: 1,
                    isLikedByCurrentUser: true
                )
            ),
            unlikeResult: .failure(MockError.failedReviewLike)
        )
        let viewModel = makeViewModel(
            reviewCommentRepository: MockReviewCommentRepository(comments: []),
            reviewRepository: reviewRepository
        )

        viewModel.send(.viewDidLoad)
        await waitUntil { viewModel.state.review != nil }

        viewModel.send(.didTapReviewLike(reviewId: "review-1"))
        XCTAssertEqual(viewModel.state.review?.likeCount, 1)
        XCTAssertEqual(viewModel.state.review?.isLikedByCurrentUser, true)
        XCTAssertTrue(viewModel.state.reactingReviewIds.contains("review-1"))

        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(viewModel.state.review?.likeCount, 1)
        XCTAssertEqual(viewModel.state.review?.isLikedByCurrentUser, true)
        XCTAssertFalse(viewModel.state.reactingReviewIds.contains("review-1"))

        viewModel.send(.didTapReviewLike(reviewId: "review-1"))
        XCTAssertEqual(viewModel.state.review?.likeCount, 0)
        XCTAssertEqual(viewModel.state.review?.isLikedByCurrentUser, false)
        XCTAssertTrue(viewModel.state.reactingReviewIds.contains("review-1"))

        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(viewModel.state.review?.likeCount, 1)
        XCTAssertEqual(viewModel.state.review?.isLikedByCurrentUser, true)
        XCTAssertFalse(viewModel.state.reactingReviewIds.contains("review-1"))
        XCTAssertEqual(reviewRepository.likeReviewCallIds, ["review-1"])
        XCTAssertEqual(reviewRepository.removeReviewLikeCallIds, ["review-1"])
    }

    func testReviewDiscussionLike_optimisticUpdateAndRollback_useCommentIdForRootAndReply() async throws {
        let rootComment = makeComment(id: "root-comment", parentCommentId: nil, depth: 0, likeCount: 0, myReaction: nil)
        let replyComment = makeComment(id: "reply-comment", parentCommentId: "root-comment", depth: 1, likeCount: 1, myReaction: nil)

        let repository = MockReviewCommentRepository(
            comments: [rootComment, replyComment],
            reactDelayNanoseconds: 50_000_000,
            reactResults: [
                "root-comment": .success(
                    makeComment(
                        id: "root-comment",
                        parentCommentId: nil,
                        depth: 0,
                        likeCount: 1,
                        myReaction: .like
                    )
                ),
                "reply-comment": .failure(MockError.failedReaction)
            ]
        )
        let viewModel = makeViewModel(reviewCommentRepository: repository)

        viewModel.send(.viewDidLoad)
        await waitUntil { viewModel.state.comments.count == 2 }

        viewModel.send(.didTapLike(commentId: rootComment.id))
        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == rootComment.id })?.likeCount, 1)
        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == rootComment.id })?.myReaction, .like)

        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == rootComment.id })?.likeCount, 1)
        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == rootComment.id })?.myReaction, .like)

        viewModel.send(.didTapLike(commentId: replyComment.id))
        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == replyComment.id })?.likeCount, 2)
        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == replyComment.id })?.myReaction, .like)

        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == replyComment.id })?.likeCount, 1)
        XCTAssertEqual(viewModel.state.comments.first(where: { $0.id == replyComment.id })?.myReaction, nil)
        XCTAssertEqual(repository.reactCallCommentIds, ["root-comment", "reply-comment"])
    }

    func testReviewDiscussionCancelComposerMode_preservesDraftWhileExitingReplyMode() async throws {
        let repository = MockReviewCommentRepository(
            comments: [makeComment(id: "root-comment", parentCommentId: nil, depth: 0, likeCount: 0, myReaction: nil)]
        )
        let viewModel = makeViewModel(reviewCommentRepository: repository)

        viewModel.send(.viewDidLoad)
        await waitUntil { viewModel.state.comments.count == 1 }

        viewModel.send(.didTapReply(commentId: "root-comment"))
        viewModel.send(.didChangeComposerText("답글 초안"))
        viewModel.send(.didTapCancelComposerMode)

        XCTAssertEqual(viewModel.state.composerMode, .comment)
        XCTAssertEqual(viewModel.state.composerText, "답글 초안")
    }

    func testReviewDiscussionReplyPrompt_routesToDetailWhenDiscussionIsNotFocusedOnComment() async throws {
        let repository = MockReviewCommentRepository(
            comments: [makeComment(id: "root-comment", parentCommentId: nil, depth: 0, likeCount: 0, myReaction: nil)]
        )
        let viewModel = makeViewModel(reviewCommentRepository: repository)
        let viewController = ReviewDiscussionViewController(
            rootView: ReviewDiscussionRootView(),
            viewModel: viewModel
        )
        let navigationController = UINavigationController(rootViewController: viewController)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigationController

        var routedCommentID: String?
        var routedReviewID: String?
        viewController.onReplyDetailRequested = { comment, review in
            routedCommentID = comment.id
            routedReviewID = review?.id
        }

        window.makeKeyAndVisible()
        viewController.loadViewIfNeeded()

        await waitUntil {
            viewController.rootView.tableView.numberOfSections == 3 &&
            viewController.rootView.tableView.numberOfRows(inSection: 2) == 1
        }

        let rootCommentIndexPath = IndexPath(row: 0, section: 2)
        viewController.rootView.tableView.scrollToRow(at: rootCommentIndexPath, at: .middle, animated: false)
        viewController.rootView.tableView.layoutIfNeeded()

        await waitUntil {
            guard let cell = viewController.rootView.tableView.cellForRow(at: rootCommentIndexPath) as? ReviewCommentCell else {
                return false
            }
            return self.findButton(in: cell.contentView, accessibilityIdentifier: "reviewComment.replyButton") != nil
        }

        guard let rootCell = viewController.rootView.tableView.cellForRow(at: rootCommentIndexPath) as? ReviewCommentCell,
              let replyButton = findButton(in: rootCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") else {
            return XCTFail("Reply prompt button not found")
        }

        replyButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(routedCommentID, "root-comment")
        XCTAssertEqual(routedReviewID, "review-1")
        XCTAssertEqual(viewModel.state.composerMode, .comment)
    }

    func testReviewDiscussionDiscussionMode_showsCTAOnlyOnLastVisibleReplyAndRoutesToDetail() async throws {
        let repository = MockReviewCommentRepository(
            comments: [
                makeComment(id: "root-comment", parentCommentId: nil, depth: 0, likeCount: 0, myReaction: nil, createdAt: 1),
                makeComment(id: "reply-1", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 2),
                makeComment(id: "reply-2", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 3),
                makeComment(id: "reply-3", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 4),
                makeComment(id: "reply-4", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 5)
            ]
        )
        let viewModel = makeViewModel(reviewCommentRepository: repository)
        let viewController = ReviewDiscussionViewController(
            rootView: ReviewDiscussionRootView(),
            viewModel: viewModel
        )
        let navigationController = UINavigationController(rootViewController: viewController)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigationController
        var routedCommentID: String?
        var routedReviewID: String?
        viewController.onReplyDetailRequested = { comment, review in
            routedCommentID = comment.id
            routedReviewID = review?.id
        }

        window.makeKeyAndVisible()
        viewController.loadViewIfNeeded()

        await waitUntil {
            viewController.rootView.tableView.numberOfSections == 3 &&
            viewController.rootView.tableView.numberOfRows(inSection: 2) == 5
        }

        let rootCommentIndexPath = IndexPath(row: 0, section: 2)
        let olderSummaryReplyIndexPath = IndexPath(row: 2, section: 2)
        let middleSummaryReplyIndexPath = IndexPath(row: 3, section: 2)
        let latestSummaryReplyIndexPath = IndexPath(row: 4, section: 2)

        viewController.rootView.tableView.scrollToRow(at: latestSummaryReplyIndexPath, at: .middle, animated: false)
        viewController.rootView.tableView.layoutIfNeeded()

        await waitUntil {
            guard let rootCell = viewController.rootView.tableView.cellForRow(at: rootCommentIndexPath) as? ReviewCommentCell,
                  let olderReplyCell = viewController.rootView.tableView.cellForRow(at: olderSummaryReplyIndexPath) as? ReviewCommentCell,
                  let middleReplyCell = viewController.rootView.tableView.cellForRow(at: middleSummaryReplyIndexPath) as? ReviewCommentCell,
                  let latestReplyCell = viewController.rootView.tableView.cellForRow(at: latestSummaryReplyIndexPath) as? ReviewCommentCell else {
                return false
            }

            return self.findButton(in: rootCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") == nil &&
                self.findButton(in: olderReplyCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") == nil &&
                self.findButton(in: middleReplyCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") == nil &&
                self.findButton(in: latestReplyCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") != nil
        }

        guard let latestReplyCell = viewController.rootView.tableView.cellForRow(at: latestSummaryReplyIndexPath) as? ReviewCommentCell,
              let latestReplyCTAButton = findButton(in: latestReplyCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") else {
            return XCTFail("Latest visible reply CTA button not found")
        }

        latestReplyCTAButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(routedCommentID, "reply-4")
        XCTAssertEqual(routedReviewID, "review-1")
        XCTAssertEqual(viewModel.state.composerMode, .comment)

        viewController.tableView(viewController.rootView.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))

        await waitUntil {
            viewController.rootView.tableView.numberOfRows(inSection: 2) == 5 &&
            viewController.rootView.tableView.cellForRow(at: IndexPath(row: 1, section: 2)) is ReviewCommentCell
        }

        let previousExpandedReplyIndexPath = IndexPath(row: 3, section: 2)
        let lastExpandedReplyIndexPath = IndexPath(row: 4, section: 2)
        viewController.rootView.tableView.scrollToRow(at: lastExpandedReplyIndexPath, at: .middle, animated: false)
        viewController.rootView.tableView.layoutIfNeeded()

        await waitUntil {
            guard let previousReplyCell = viewController.rootView.tableView.cellForRow(at: previousExpandedReplyIndexPath) as? ReviewCommentCell,
                  let latestReplyCell = viewController.rootView.tableView.cellForRow(at: lastExpandedReplyIndexPath) as? ReviewCommentCell else {
                return false
            }

            return self.findButton(in: previousReplyCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") == nil &&
                self.findButton(in: latestReplyCell.contentView, accessibilityIdentifier: "reviewComment.replyButton") != nil
        }

        viewController.tableView(viewController.rootView.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))
        XCTAssertEqual(viewController.rootView.tableView.numberOfRows(inSection: 2), 5)
    }

    func testReviewDiscussionSubmitReply_keepsCollapsedLatestSummaryInCommentDetail() async throws {
        let repository = MockReviewCommentRepository(
            comments: [
                makeComment(id: "root-comment", parentCommentId: nil, depth: 0, likeCount: 0, myReaction: nil, createdAt: 1),
                makeComment(id: "reply-1", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 2),
                makeComment(id: "reply-2", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 3),
                makeComment(id: "reply-3", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 4)
            ]
        )
        let viewModel = makeViewModel(
            reviewCommentRepository: repository,
            highlightCommentId: "root-comment"
        )

        viewModel.send(.viewDidLoad)
        await waitUntil { viewModel.state.comments.count == 4 }

        XCTAssertFalse(viewModel.state.expandedParentCommentIds.contains("root-comment"))

        viewModel.send(.didTapReply(commentId: "reply-3"))
        viewModel.send(.didChangeComposerText("새 답글"))
        viewModel.send(.didTapSubmit)

        await waitUntil {
            viewModel.state.comments.count == 5 && viewModel.state.isSubmitting == false
        }

        let threadState = try XCTUnwrap(viewModel.state.commentThreadStates.first)
        XCTAssertFalse(viewModel.state.expandedParentCommentIds.contains("root-comment"))
        XCTAssertEqual(threadState.visibleReplies.map(\.id), ["reply-2", "reply-3", "created-5"])
        XCTAssertEqual(threadState.lastVisibleReplyId, "created-5")
        XCTAssertNil(threadState.threadCTATargetCommentId)
        XCTAssertEqual(repository.createDrafts.first?.parentCommentId, "root-comment")
        XCTAssertEqual(repository.createDrafts.first?.content, "새 답글")
    }

    func testReviewDiscussionReplyDetail_hidesCTAAndKeepsLayoutStableAcrossToggle() async throws {
        let repository = MockReviewCommentRepository(
            comments: [
                makeComment(id: "root-comment", parentCommentId: nil, depth: 0, likeCount: 0, myReaction: nil, createdAt: 1),
                makeComment(id: "reply-1", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 2),
                makeComment(id: "reply-2", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 3),
                makeComment(id: "reply-3", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 4),
                makeComment(id: "reply-4", parentCommentId: "root-comment", depth: 1, likeCount: 0, myReaction: nil, createdAt: 5)
            ]
        )
        let viewModel = makeViewModel(
            reviewCommentRepository: repository,
            highlightCommentId: "reply-4"
        )
        let viewController = ReviewDiscussionViewController(
            rootView: ReviewDiscussionRootView(),
            viewModel: viewModel
        )
        let navigationController = UINavigationController(rootViewController: viewController)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = navigationController

        window.makeKeyAndVisible()
        viewController.loadViewIfNeeded()

        await waitUntil {
            viewController.rootView.tableView.numberOfSections == 3 &&
            viewController.rootView.tableView.numberOfRows(inSection: 2) == 5
        }

        viewController.rootView.tableView.layoutIfNeeded()
        assertVisibleRowLayoutIsStable(in: viewController.rootView.tableView, section: 2)

        for row in 0..<viewController.rootView.tableView.numberOfRows(inSection: 2) {
            let indexPath = IndexPath(row: row, section: 2)
            guard let cell = viewController.rootView.tableView.cellForRow(at: indexPath) as? ReviewCommentCell else {
                continue
            }
            XCTAssertNil(findButton(in: cell.contentView, accessibilityIdentifier: "reviewComment.replyButton"))
        }

        viewController.tableView(viewController.rootView.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))

        await waitUntil {
            viewController.rootView.tableView.numberOfRows(inSection: 2) == 5 &&
            viewController.rootView.tableView.cellForRow(at: IndexPath(row: 1, section: 2)) is ReviewCommentCell
        }

        viewController.rootView.tableView.layoutIfNeeded()
        assertVisibleRowLayoutIsStable(in: viewController.rootView.tableView, section: 2)

        for row in 0..<viewController.rootView.tableView.numberOfRows(inSection: 2) {
            let indexPath = IndexPath(row: row, section: 2)
            guard let cell = viewController.rootView.tableView.cellForRow(at: indexPath) as? ReviewCommentCell else {
                continue
            }
            XCTAssertNil(findButton(in: cell.contentView, accessibilityIdentifier: "reviewComment.replyButton"))
        }

        viewController.tableView(viewController.rootView.tableView, didSelectRowAt: IndexPath(row: 1, section: 2))
        XCTAssertEqual(viewController.rootView.tableView.numberOfRows(inSection: 2), 5)
        viewController.rootView.tableView.layoutIfNeeded()
        assertVisibleRowLayoutIsStable(in: viewController.rootView.tableView, section: 2)
    }

    func testGameReviewsViewModel_reviewLike_optimisticUpdateRollbackAndDiscussionSync() async throws {
        let initialReview = makeReview(commentCount: 2)
        let reviewRepository = MockReviewRepository(
            fetchGameReviewsResult: .success(
                GameReviewFeed(
                    reviews: [initialReview],
                    summary: ReviewSummary(reviewCount: 1, averageRating: initialReview.rating)
                )
            ),
            likeDelayNanoseconds: 50_000_000,
            likeResult: .success(
                ReviewLikeMutationResult(
                    reviewId: "review-1",
                    likeCount: 1,
                    isLikedByCurrentUser: true
                )
            ),
            unlikeResult: .failure(MockError.failedReviewLike)
        )
        let commentRepository = MockReviewCommentRepository(comments: [])
        let gameReviewsViewModel = GameReviewsViewModel(
            gameId: 10,
            gameTitle: "테스트 게임",
            fetchGameReviewsUseCase: FetchGameReviewsUseCase(reviewRepository: reviewRepository),
            toggleReviewLikeUseCase: ToggleReviewLikeUseCase(reviewRepository: reviewRepository),
            reviewCommentRepository: commentRepository
        )
        let discussionViewModel = makeViewModel(
            reviewCommentRepository: commentRepository,
            reviewRepository: reviewRepository
        )

        gameReviewsViewModel.loadReviews()
        await waitUntil { gameReviewsViewModel.state.reviews.count == 1 }

        discussionViewModel.send(.viewDidLoad)
        await waitUntil { discussionViewModel.state.review != nil }

        gameReviewsViewModel.toggleReviewLike(reviewId: "review-1")
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.likeCount, 1)
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.isLikedByCurrentUser, true)
        XCTAssertTrue(gameReviewsViewModel.state.reactingReviewIds.contains("review-1"))

        await waitUntil {
            discussionViewModel.state.review?.likeCount == 1 &&
            discussionViewModel.state.review?.isLikedByCurrentUser == true
        }

        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertFalse(gameReviewsViewModel.state.reactingReviewIds.contains("review-1"))
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.likeCount, 1)
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.isLikedByCurrentUser, true)

        gameReviewsViewModel.toggleReviewLike(reviewId: "review-1")
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.likeCount, 0)
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.isLikedByCurrentUser, false)
        XCTAssertTrue(gameReviewsViewModel.state.reactingReviewIds.contains("review-1"))

        await waitUntil {
            discussionViewModel.state.review?.likeCount == 0 &&
            discussionViewModel.state.review?.isLikedByCurrentUser == false
        }

        try await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertFalse(gameReviewsViewModel.state.reactingReviewIds.contains("review-1"))
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.likeCount, 1)
        XCTAssertEqual(gameReviewsViewModel.state.reviews.first?.isLikedByCurrentUser, true)
        XCTAssertEqual(discussionViewModel.state.review?.likeCount, 1)
        XCTAssertEqual(discussionViewModel.state.review?.isLikedByCurrentUser, true)
        XCTAssertEqual(reviewRepository.likeReviewCallIds, ["review-1"])
        XCTAssertEqual(reviewRepository.removeReviewLikeCallIds, ["review-1"])
    }

    private func waitUntil(
        timeout: TimeInterval = 1.5,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            await Task.yield()
        }
        XCTFail("Timed out waiting for condition")
    }

    private func makeViewModel(
        reviewCommentRepository: any ReviewCommentRepository,
        reviewRepository: any ReviewRepository = MockReviewRepository(),
        highlightCommentId: String? = nil
    ) -> ReviewDiscussionViewModel {
        ReviewDiscussionViewModel(
            gameId: 10,
            gameTitle: "테스트 게임",
            reviewId: "review-1",
            reviewSeed: makeReview(),
            highlightCommentId: highlightCommentId,
            toggleReviewLikeUseCase: ToggleReviewLikeUseCase(reviewRepository: reviewRepository),
            reviewCommentRepository: reviewCommentRepository
        )
    }

    private func makeReview(
        id: String = "review-1",
        gameId: String = "10",
        likeCount: Int = 0,
        commentCount: Int = 2,
        isLikedByCurrentUser: Bool = false
    ) -> Review {
        Review(
            id: id,
            gameId: gameId,
            rating: 4.5,
            content: "리뷰 본문",
            createdAt: "2026-04-07T00:00:00Z",
            updatedAt: "2026-04-07T00:00:00Z",
            author: ReviewAuthor(
                id: "review-author",
                nickname: "리뷰작성자",
                profileImageUrl: nil
            ),
            isMine: false,
            likeCount: likeCount,
            commentCount: commentCount,
            isLikedByCurrentUser: isLikedByCurrentUser
        )
    }

    private func makeComment(
        id: String,
        parentCommentId: String?,
        depth: Int,
        likeCount: Int,
        myReaction: ReviewCommentReaction?,
        createdAt: TimeInterval? = nil
    ) -> ReviewComment {
        ReviewComment(
            id: id,
            reviewId: "review-1",
            gameId: 10,
            gameTitle: "테스트 게임",
            reviewSnippet: "리뷰 본문",
            parentCommentId: parentCommentId,
            depth: depth,
            author: ReviewCommentAuthor(
                id: "author-\(id)",
                nickname: "작성자-\(id)",
                profileImageUrl: nil
            ),
            content: "댓글-\(id)",
            createdAt: Date(timeIntervalSince1970: createdAt ?? (depth == 0 ? 1 : 2)),
            updatedAt: nil,
            isMine: false,
            isReviewAuthor: false,
            isDeleted: false,
            isEdited: false,
            replyCount: 0,
            likeCount: likeCount,
            dislikeCount: 0,
            myReaction: myReaction
        )
    }

    private func makeReplyMode(
        targetCommentId: String,
        parentCommentId: String,
        nickname: String,
        previewText: String,
        isSelfReply: Bool
    ) -> ReviewDiscussionComposerMode {
        .reply(.init(
            parentCommentId: parentCommentId,
            targetCommentId: targetCommentId,
            targetNickname: nickname,
            targetPreviewText: previewText,
            isSelfReply: isSelfReply
        ))
    }

    private func findButton(in view: UIView, accessibilityIdentifier: String) -> UIButton? {
        if let button = view as? UIButton {
            if button.accessibilityIdentifier == accessibilityIdentifier,
               button.isHidden == false,
               button.alpha > 0.01 {
                return button
            }
        }
        for subview in view.subviews {
            if let button = findButton(in: subview, accessibilityIdentifier: accessibilityIdentifier) {
                return button
            }
        }
        return nil
    }

    private func findButton(in view: UIView, accessibilityLabel: String) -> UIButton? {
        if let button = view as? UIButton {
            if button.accessibilityLabel == accessibilityLabel,
               button.isHidden == false,
               button.alpha > 0.01 {
                return button
            }
        }
        for subview in view.subviews {
            if let button = findButton(in: subview, accessibilityLabel: accessibilityLabel) {
                return button
            }
        }
        return nil
    }

    private func assertVisibleRowLayoutIsStable(in tableView: UITableView, section: Int) {
        var previousMaxY: CGFloat = -.greatestFiniteMagnitude
        for row in 0..<tableView.numberOfRows(inSection: section) {
            let indexPath = IndexPath(row: row, section: section)
            let rect = tableView.rectForRow(at: indexPath)
            XCTAssertGreaterThan(rect.height, 0)
            XCTAssertGreaterThanOrEqual(rect.minY, previousMaxY)
            previousMaxY = rect.maxY
        }
    }
}

private final class MockReviewRepository: ReviewRepository {
    let fetchGameReviewsResult: Result<GameReviewFeed, Error>?
    let likeDelayNanoseconds: UInt64
    let likeResult: Result<ReviewLikeMutationResult, Error>
    let unlikeResult: Result<ReviewLikeMutationResult, Error>
    private(set) var likeReviewCallIds: [String] = []
    private(set) var removeReviewLikeCallIds: [String] = []

    init(
        fetchGameReviewsResult: Result<GameReviewFeed, Error>? = nil,
        likeDelayNanoseconds: UInt64 = 0,
        likeResult: Result<ReviewLikeMutationResult, Error> = .success(
            ReviewLikeMutationResult(reviewId: "review-1", likeCount: 1, isLikedByCurrentUser: true)
        ),
        unlikeResult: Result<ReviewLikeMutationResult, Error> = .success(
            ReviewLikeMutationResult(reviewId: "review-1", likeCount: 0, isLikedByCurrentUser: false)
        )
    ) {
        self.fetchGameReviewsResult = fetchGameReviewsResult
        self.likeDelayNanoseconds = likeDelayNanoseconds
        self.likeResult = likeResult
        self.unlikeResult = unlikeResult
    }

    func createReview(gameId: String, rating: Double, content: String) async throws -> Review {
        throw MockError.unused
    }

    func fetchGameReviews(gameId: String, sort: ReviewSortOption?) async throws -> GameReviewFeed {
        guard let fetchGameReviewsResult else {
            throw MockError.unused
        }
        switch fetchGameReviewsResult {
        case .success(let feed):
            return feed
        case .failure(let error):
            throw error
        }
    }

    func updateReview(reviewId: String, rating: Double?, content: String?) async throws -> Review {
        throw MockError.unused
    }

    func deleteReview(reviewId: String) async throws -> ReviewDeletionResult {
        throw MockError.unused
    }

    func fetchMyReviews(sort: ReviewSortOption?) async throws -> [Review] {
        throw MockError.unused
    }

    func likeReview(reviewId: String) async throws -> ReviewLikeMutationResult {
        likeReviewCallIds.append(reviewId)
        if likeDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: likeDelayNanoseconds)
        }
        switch likeResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    func removeReviewLike(reviewId: String) async throws -> ReviewLikeMutationResult {
        removeReviewLikeCallIds.append(reviewId)
        if likeDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: likeDelayNanoseconds)
        }
        switch unlikeResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

private final class MockReviewCommentRepository: ReviewCommentRepository {
    var comments: [ReviewComment]
    let reactDelayNanoseconds: UInt64
    let reactResults: [String: Result<ReviewComment, Error>]
    private(set) var reactCallCommentIds: [String] = []
    private(set) var createDrafts: [ReviewCommentDraft] = []

    init(
        comments: [ReviewComment],
        reactDelayNanoseconds: UInt64 = 0,
        reactResults: [String: Result<ReviewComment, Error>] = [:]
    ) {
        self.comments = comments
        self.reactDelayNanoseconds = reactDelayNanoseconds
        self.reactResults = reactResults
    }

    func fetchComments(for context: ReviewDiscussionContext) async throws -> [ReviewComment] {
        comments.filter { $0.reviewId == context.reviewId }
    }

    func createComment(draft: ReviewCommentDraft, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        createDrafts.append(draft)
        let nextTimestamp = (comments.map { $0.createdAt.timeIntervalSince1970 }.max() ?? 0) + 1
        let createdComment = ReviewComment(
            id: "created-\(comments.count + 1)",
            reviewId: context.reviewId,
            gameId: context.gameId,
            gameTitle: context.gameTitle,
            reviewSnippet: context.reviewSnippet,
            parentCommentId: draft.parentCommentId,
            depth: draft.parentCommentId == nil ? 0 : 1,
            author: ReviewCommentAuthor(
                id: "created-author",
                nickname: "생성작성자",
                profileImageUrl: nil
            ),
            content: draft.content,
            createdAt: Date(timeIntervalSince1970: nextTimestamp),
            updatedAt: nil,
            isMine: true,
            isReviewAuthor: false,
            isDeleted: false,
            isEdited: false,
            replyCount: 0,
            likeCount: 0,
            dislikeCount: 0,
            myReaction: nil
        )
        comments.append(createdComment)
        return createdComment
    }

    func updateComment(commentId: String, content: String, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        throw MockError.unused
    }

    func deleteComment(commentId: String, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        throw MockError.unused
    }

    func react(to commentId: String, reaction: ReviewCommentReaction?, in context: ReviewDiscussionContext) async throws -> ReviewComment {
        reactCallCommentIds.append(commentId)
        if reactDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: reactDelayNanoseconds)
        }
        if let result = reactResults[commentId] {
            switch result {
            case .success(let updatedComment):
                replaceComment(updatedComment)
                return updatedComment
            case .failure(let error):
                throw error
            }
        }

        guard let comment = comments.first(where: { $0.id == commentId }) else {
            throw MockError.missingComment
        }
        let updatedComment = ReviewComment(
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
            likeCount: reaction == .like ? comment.likeCount + 1 : comment.likeCount,
            dislikeCount: comment.dislikeCount,
            myReaction: reaction
        )
        replaceComment(updatedComment)
        return updatedComment
    }

    func react(to commentId: String, reaction: ReviewCommentReaction?) async throws -> ReviewComment {
        throw MockError.unused
    }

    func fetchCommentCounts(reviewIds: [String]) async throws -> [String : Int] {
        [:]
    }

    func fetchMyComments() async throws -> [MyReviewCommentEntry] {
        []
    }

    func fetchLocalNotifications() async -> [AppNotification] {
        []
    }

    func markAllLocalNotificationsRead() async {}

    private func replaceComment(_ updatedComment: ReviewComment) {
        guard let index = comments.firstIndex(where: { $0.id == updatedComment.id }) else { return }
        comments[index] = updatedComment
    }
}

private enum MockError: LocalizedError {
    case unused
    case missingComment
    case failedReaction
    case failedReviewLike

    var errorDescription: String? {
        switch self {
        case .unused:
            return "unused"
        case .missingComment:
            return "missing-comment"
        case .failedReaction:
            return "failed-reaction"
        case .failedReviewLike:
            return "failed-review-like"
        }
    }
}
