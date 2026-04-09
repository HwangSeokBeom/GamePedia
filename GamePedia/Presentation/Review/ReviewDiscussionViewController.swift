import UIKit

final class ReviewDiscussionViewController: BaseViewController<ReviewDiscussionRootView, ReviewDiscussionState> {
    private enum Section: String {
        case reviewHeaderCard
        case discussionHeader
        case emptyState
        case comments
    }

    private enum TableTapTarget {
        case background
        case reviewHeaderCard
        case discussionArea
        case commentCell(String)
        case toggleReplies(String)
    }

    private enum ReplyEntrySource {
        case direct
        case cta
    }

    private enum Row: Hashable {
        case reviewHeaderCard(String)
        case discussionHeader(String)
        case emptyState(String)
        case comment(String)
        case toggleReplies(parentCommentId: String, hiddenCount: Int, expanded: Bool)
    }

    private struct SnapshotSectionSignature: Equatable {
        let section: Section
        let rows: [Row]
    }

    private struct SnapshotSignature: Equatable {
        let sections: [SnapshotSectionSignature]
    }

    private struct ReplyToggleAnchor {
        let parentCommentId: String
        let minY: CGFloat
    }

    private struct ReplyPromptConfiguration {
        let title: String?
        let targetCommentId: String?
    }

    private let viewModel: ReviewDiscussionViewModel
    private let shouldAutoFocusReplyComposerOnFirstAppearance: Bool
    private let requestedInitialReplyTargetCommentId: String?
    private var dataSource: UITableViewDiffableDataSource<Section, Row>!
    private var commentById: [String: ReviewComment] = [:]
    private var replyPromptByAnchorCommentId: [String: ReplyPromptConfiguration] = [:]
    private var lastRenderedSnapshotSignature: SnapshotSignature?
    private var currentReviewHeaderState: ReviewDiscussionHeaderState?
    private var currentDiscussionSectionState: ReviewDiscussionSectionState?
    private var currentSortMenu: UIMenu?
    private var lastHighlightToken: Int = 0
    private var keyboardDismissTapGestureRecognizer: UITapGestureRecognizer?
    private var navigationBarTapGestureRecognizer: UITapGestureRecognizer?
    private var pendingInitialReplyTargetCommentId: String?
    private var hasViewAppeared = false
    private var pendingReplyToggleAnchor: ReplyToggleAnchor?

    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?
    var onReplyDetailRequested: ((ReviewComment, Review?) -> Void)?
    var gameId: Int { viewModel.state.gameId }
    var reviewId: String { viewModel.state.reviewId }
    var initialGameTitle: String? { viewModel.state.initialGameTitle }
    var initialHighlightCommentId: String? { viewModel.state.initialHighlightCommentId }
    var initialReplyTargetCommentId: String? { requestedInitialReplyTargetCommentId }

    init(
        rootView: ReviewDiscussionRootView,
        viewModel: ReviewDiscussionViewModel,
        initialReplyTargetCommentId: String? = nil,
        autoFocusReplyComposerOnFirstAppearance: Bool = false
    ) {
        self.viewModel = viewModel
        self.requestedInitialReplyTargetCommentId = initialReplyTargetCommentId
        self.pendingInitialReplyTargetCommentId = initialReplyTargetCommentId
        self.shouldAutoFocusReplyComposerOnFirstAppearance = autoFocusReplyComposerOnFirstAppearance
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ReviewDiscussionTrace.log(
            "[ReviewDiscussionVC] viewDidLoad viewController=\(String(describing: type(of: self))) viewModel=\(String(describing: type(of: viewModel))) rootView=\(String(describing: type(of: rootView)))"
        )
        navigationItem.largeTitleDisplayMode = .never
        setupTableView()
        setupComposer()
        setupKeyboardDismissGesture()
        setupKeyboardObservers()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBarDismissGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasViewAppeared = true
        activateInitialReplyTargetIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    deinit {
        if let navigationBarTapGestureRecognizer {
            navigationController?.navigationBar.removeGestureRecognizer(navigationBarTapGestureRecognizer)
        }
        NotificationCenter.default.removeObserver(self)
    }

    override func render(_ state: ReviewDiscussionState) {
        ReviewDiscussionTrace.log(
            "[ReviewDiscussionVC] render comments=\(state.comments.count) composerMode=\(state.composerMode.traceName) reacting=\(state.reactingCommentIds.count)"
        )
        navigationItem.title = state.navigationTitle
        rootView.render(state)
        applySnapshotIfNeeded(for: state)
        refreshVisibleRows(for: state)

        if let errorMessage = state.errorMessage, state.review == nil {
            let alert = UIAlertController(title: L10n.Common.Error.title, message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
            if presentedViewController == nil {
                present(alert, animated: true)
            }
        }

        if state.highlightToken != lastHighlightToken, let commentId = state.highlightedCommentId {
            lastHighlightToken = state.highlightToken
            highlightCommentIfNeeded(commentId: commentId)
        }

        activateInitialReplyTargetIfNeeded()
    }

    private func setupTableView() {
        rootView.tableView.register(ReviewDiscussionHeaderCardCell.self, forCellReuseIdentifier: ReviewDiscussionHeaderCardCell.reuseIdentifier)
        rootView.tableView.register(ReviewDiscussionSectionHeaderCell.self, forCellReuseIdentifier: ReviewDiscussionSectionHeaderCell.reuseIdentifier)
        rootView.tableView.register(ReviewDiscussionEmptyStateCell.self, forCellReuseIdentifier: ReviewDiscussionEmptyStateCell.reuseIdentifier)
        rootView.tableView.register(ReplyToggleCell.self, forCellReuseIdentifier: ReplyToggleCell.reuseIdentifier)
        dataSource = UITableViewDiffableDataSource<Section, Row>(tableView: rootView.tableView) { [weak self] tableView, indexPath, row in
            guard let self else { return UITableViewCell() }
            switch row {
            case .reviewHeaderCard:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReviewDiscussionHeaderCardCell.reuseIdentifier, for: indexPath) as! ReviewDiscussionHeaderCardCell
                if let headerState = self.currentReviewHeaderState {
                    cell.configure(with: headerState)
                    cell.onLikeTapped = { [weak self] in
                        self?.performAuthenticatedAction {
                            ReviewDiscussionTrace.log("[ReviewDiscussionVC] didTapReviewLike reviewId=\(headerState.review.id)")
                            self?.viewModel.send(.didTapReviewLike(reviewId: headerState.review.id))
                        }
                    }
                }
                return cell
            case .discussionHeader:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReviewDiscussionSectionHeaderCell.reuseIdentifier, for: indexPath) as! ReviewDiscussionSectionHeaderCell
                if let sectionState = self.currentDiscussionSectionState {
                    cell.configure(with: sectionState, sortMenu: self.currentSortMenu)
                    cell.onSortButtonTouchDown = { [weak self] in
                        self?.keyboardDismissOnly()
                    }
                }
                return cell
            case .emptyState:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReviewDiscussionEmptyStateCell.reuseIdentifier, for: indexPath) as! ReviewDiscussionEmptyStateCell
                cell.configure(
                    title: L10n.tr("Localizable", "review.comment.empty.title"),
                    message: L10n.tr("Localizable", "review.comment.empty.subtitle"),
                    buttonTitle: self.viewModel.state.emptyStateActionTitle
                )
                cell.onActionTapped = { [weak self] in
                    self?.didTapEmptyStateAction()
                }
                return cell
            case .comment(let commentId):
                let cell = tableView.dequeueReusableCell(withIdentifier: ReviewCommentCell.reuseIdentifier, for: indexPath) as! ReviewCommentCell
                guard let comment = self.commentById[commentId] else { return cell }
                self.configure(cell, with: comment, reactingCommentIds: self.viewModel.state.reactingCommentIds)
                return cell
            case .toggleReplies(_, let hiddenCount, let expanded):
                let cell = tableView.dequeueReusableCell(withIdentifier: ReplyToggleCell.reuseIdentifier, for: indexPath) as! ReplyToggleCell
                cell.configure(hiddenCount: hiddenCount, expanded: expanded)
                return cell
            }
        }
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
    }

    private func setupComposer() {
        rootView.retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        rootView.submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        rootView.cancelComposerModeButton.addTarget(self, action: #selector(didTapCancelComposerMode), for: .touchUpInside)
        rootView.composerTextView.delegate = self
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
        render(viewModel.state)
    }

    private func makeSortMenu(selected: ReviewCommentSortOption) -> UIMenu {
        let actions = ReviewCommentSortOption.allCases.map { option in
            UIAction(title: option.displayTitle, state: option == selected ? .on : .off) { [weak self] _ in
                self?.viewModel.send(.didChangeSort(option))
            }
        }
        return UIMenu(children: actions)
    }

    private func applySnapshotIfNeeded(for state: ReviewDiscussionState) {
        currentReviewHeaderState = state.reviewHeaderState
        currentDiscussionSectionState = state.discussionSectionState
        currentSortMenu = makeSortMenu(selected: state.sortOption)

        let screenType = state.discussionScreenType
        let threadStates = state.commentThreadStates
        updateReplyPromptMappings(from: threadStates)
        let commentRows = makeRows(from: threadStates, screenType: screenType)
        commentById = MappingSafety.dictionary(
            pairs: state.comments.map { ($0.id, $0) },
            logPrefix: "[CommentMapping]",
            keyName: "commentId",
            countLabel: "commentCount",
            screen: "ReviewDiscussionViewController.applySnapshotIfNeeded",
            mergePolicy: .keepFirst
        )
        let signature = makeSnapshotSignature(for: state, commentRows: commentRows)
        guard signature != lastRenderedSnapshotSignature else { return }
        lastRenderedSnapshotSignature = signature

        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        signature.sections.forEach { section in
            snapshot.appendSections([section.section])
            snapshot.appendItems(section.rows, toSection: section.section)
        }
        if screenType.isFocusedThreadScreen {
            dataSource.applySnapshotUsingReloadData(snapshot)
            rootView.tableView.layoutIfNeeded()
            restoreReplyToggleAnchorIfNeeded()
        } else {
            dataSource.apply(snapshot, animatingDifferences: true) { [weak self] in
                self?.rootView.tableView.layoutIfNeeded()
                self?.restoreReplyToggleAnchorIfNeeded()
            }
        }
    }

    private func makeSnapshotSignature(for state: ReviewDiscussionState, commentRows: [Row]) -> SnapshotSignature {
        var sections: [SnapshotSectionSignature] = []

        if let headerState = state.reviewHeaderState {
            sections.append(.init(
                section: .reviewHeaderCard,
                rows: [.reviewHeaderCard(headerState.review.id)]
            ))
        }

        if state.discussionSectionState != nil {
            sections.append(.init(
                section: .discussionHeader,
                rows: [.discussionHeader(state.reviewId)]
            ))
        }

        switch state.discussionContentState {
        case .loading:
            if !commentRows.isEmpty {
                sections.append(.init(section: .comments, rows: commentRows))
            }
        case .empty:
            sections.append(.init(
                section: .emptyState,
                rows: [.emptyState(state.reviewId)]
            ))
        case .populated:
            sections.append(.init(section: .comments, rows: commentRows))
        }

        return SnapshotSignature(sections: sections)
    }

    private func updateReplyPromptMappings(from threadStates: [ReviewDiscussionCommentThreadState]) {
        replyPromptByAnchorCommentId = threadStates.reduce(into: [:]) { mapping, threadState in
            guard threadState.shouldShowThreadCTA,
                  let anchorCommentId = threadState.threadCTAAnchorCommentId,
                  let targetCommentId = threadState.threadCTATargetCommentId,
                  let title = threadState.threadCTATitle else {
                return
            }
            mapping[anchorCommentId] = .init(
                title: title,
                targetCommentId: targetCommentId
            )
        }
    }

    private func makeRows(
        from threadStates: [ReviewDiscussionCommentThreadState],
        screenType: ReviewDiscussionScreenType
    ) -> [Row] {
        var rows: [Row] = []

        for threadState in threadStates {
            rows.append(.comment(threadState.rootComment.id))
            guard !threadState.allReplies.isEmpty else { continue }

            let showsToggleAboveReplies = screenType.prefersToggleAboveReplies

            if showsToggleAboveReplies, threadState.shouldShowExpandButton {
                rows.append(.toggleReplies(
                    parentCommentId: threadState.parentCommentId,
                    hiddenCount: threadState.hiddenOlderRepliesCount,
                    expanded: false
                ))
            }

            rows.append(contentsOf: threadState.visibleReplies.map { .comment($0.id) })

            if !showsToggleAboveReplies, threadState.shouldShowExpandButton {
                rows.append(.toggleReplies(
                    parentCommentId: threadState.parentCommentId,
                    hiddenCount: threadState.hiddenOlderRepliesCount,
                    expanded: false
                ))
            }
        }

        return rows
    }

    private func highlightCommentIfNeeded(commentId: String) {
        guard let indexPath = dataSource.indexPath(for: .comment(commentId)) else { return }
        rootView.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let cell = self.rootView.tableView.cellForRow(at: indexPath) as? ReviewCommentCell {
                cell.animateHighlight()
            }
        }
    }

    private func refreshVisibleRows(for state: ReviewDiscussionState) {
        if let headerState = state.reviewHeaderState,
           let indexPath = dataSource.indexPath(for: .reviewHeaderCard(headerState.review.id)),
           let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewDiscussionHeaderCardCell {
            cell.configure(with: headerState)
            cell.onLikeTapped = { [weak self] in
                self?.performAuthenticatedAction {
                    ReviewDiscussionTrace.log("[ReviewDiscussionVC] didTapReviewLike reviewId=\(headerState.review.id)")
                    self?.viewModel.send(.didTapReviewLike(reviewId: headerState.review.id))
                }
            }
        }

        if let discussionSectionState = state.discussionSectionState,
           let indexPath = dataSource.indexPath(for: .discussionHeader(state.reviewId)),
           let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewDiscussionSectionHeaderCell {
            cell.configure(with: discussionSectionState, sortMenu: currentSortMenu)
            cell.onSortButtonTouchDown = { [weak self] in
                self?.keyboardDismissOnly()
            }
        }

        if let indexPath = dataSource.indexPath(for: .emptyState(state.reviewId)),
           let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewDiscussionEmptyStateCell {
            cell.configure(
                title: L10n.tr("Localizable", "review.comment.empty.title"),
                message: L10n.tr("Localizable", "review.comment.empty.subtitle"),
                buttonTitle: state.emptyStateActionTitle
            )
        }

        state.comments.forEach { comment in
            guard let indexPath = dataSource.indexPath(for: .comment(comment.id)),
                  let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewCommentCell else {
                return
            }

            configure(cell, with: comment, reactingCommentIds: state.reactingCommentIds)
        }
    }

    private func configure(
        _ cell: ReviewCommentCell,
        with comment: ReviewComment,
        reactingCommentIds: Set<String>
    ) {
        let replyPrompt = replyPromptConfiguration(for: comment)
        cell.configure(with: .init(
            id: comment.id,
            authorName: comment.author.nickname,
            authorAvatarURL: comment.author.avatarURL,
            bodyText: comment.content,
            dateText: comment.formattedDate,
            depth: comment.depth,
            isMine: comment.isMine,
            isDeleted: comment.isDeleted,
            likeCount: comment.likeCount,
            myReaction: comment.myReaction,
            isReactionLoading: reactingCommentIds.contains(comment.id),
            canReply: comment.canReply,
            replyPromptTitle: replyPrompt.title,
            isReplyPromptEnabled: replyPrompt.targetCommentId != nil,
            showsMoreAction: availableCommentActionKinds(for: comment).isEmpty == false
        ))
        cell.onLikeTapped = { [weak self] in
            self?.performAuthenticatedAction {
                ReviewDiscussionTrace.log("[ReviewDiscussionVC] didTapLike commentId=\(comment.id)")
                self?.viewModel.send(.didTapLike(commentId: comment.id))
            }
        }
        cell.onReplyTapped = { [weak self] in
            guard let self, let targetCommentId = replyPrompt.targetCommentId,
                  let targetComment = self.commentById[targetCommentId] else {
                return
            }

            let source: ReplyEntrySource = self.viewModel.state.discussionScreenType.allowsThreadCTA ? .cta : .direct
            self.performAuthenticatedAction { [weak self] in
                self?.handleReplyEntry(for: targetComment, source: source)
            }
        }
        cell.onMoreTapped = { [weak self] in
            self?.presentCommentActionSheet(for: comment)
        }
    }

    private func replyPromptConfiguration(for comment: ReviewComment) -> ReplyPromptConfiguration {
        guard let promptConfiguration = replyPromptByAnchorCommentId[comment.id] else {
            return .init(title: nil, targetCommentId: nil)
        }
        return promptConfiguration
    }

    private func performAuthenticatedAction(
        for context: RestrictedActionContext = .viewReviews,
        _ action: @escaping () -> Void
    ) {
        guard let onAuthenticationRequired else {
            action()
            return
        }
        onAuthenticationRequired(context, action)
    }

    private func setupKeyboardDismissGesture() {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleKeyboardDismissTap(_:)))
        gestureRecognizer.cancelsTouchesInView = true
        gestureRecognizer.delegate = self
        rootView.tableView.addGestureRecognizer(gestureRecognizer)
        keyboardDismissTapGestureRecognizer = gestureRecognizer
    }

    private func setupNavigationBarDismissGesture() {
        guard navigationBarTapGestureRecognizer == nil,
              let navigationBar = navigationController?.navigationBar else {
            return
        }

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleNavigationBarTap(_:)))
        gestureRecognizer.cancelsTouchesInView = false
        gestureRecognizer.delegate = self
        navigationBar.addGestureRecognizer(gestureRecognizer)
        navigationBarTapGestureRecognizer = gestureRecognizer
    }

    @objc private func didTapRetry() {
        viewModel.send(.didTapRetry)
    }

    @objc private func didTapEmptyStateAction() {
        handleTapTarget(.discussionArea)
    }

    @objc private func didTapSubmit() {
        performAuthenticatedAction { [weak self] in
            self?.viewModel.send(.didTapSubmit)
        }
    }

    @objc private func didTapCancelComposerMode() {
        viewModel.send(.didTapCancelComposerMode)
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        updateComposerBottomInset(to: 0, notification: notification)
    }

    @objc private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let keyboardFrameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        let keyboardFrame = view.convert(keyboardFrameValue.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY - view.safeAreaInsets.bottom)
        updateComposerBottomInset(to: overlap, notification: notification)
    }

    @objc private func handleKeyboardDismissTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }
        let location = gestureRecognizer.location(in: rootView.tableView)
        handleTableTap(at: location)
    }

    @objc private func handleNavigationBarTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended,
              navigationController?.topViewController === self else {
            return
        }
        ReviewDiscussionTrace.log("[ReviewDiscussionVC] tapHit target=navigationBar")
        keyboardDismissOnly()
    }

    private func updateComposerBottomInset(to inset: CGFloat, notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRawValue = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue
            ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let options = UIView.AnimationOptions(rawValue: UInt(curveRawValue << 16))
        rootView.setComposerBottomInset(inset)
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            self.view.layoutIfNeeded()
        }
    }

    private func handleTapTarget(_ target: TableTapTarget) {
        switch target {
        case .background:
            ReviewDiscussionTrace.log("[ReviewDiscussionVC] tapHit target=background")
            keyboardDismissOnly()
        case .reviewHeaderCard:
            ReviewDiscussionTrace.log("[ReviewDiscussionVC] tapHit target=reviewHeaderCard")
            keyboardDismissOnly()
        case .discussionArea:
            ReviewDiscussionTrace.log("[ReviewDiscussionVC] tapHit target=discussionArea")
            viewModel.send(.didTapDiscussionArea)
            focusComposer(mode: .comment)
        case .commentCell(let commentId):
            ReviewDiscussionTrace.log("[ReviewDiscussionVC] tapHit target=commentCell commentId=\(commentId)")
            keyboardDismissOnly()
        case .toggleReplies(let parentCommentId):
            keyboardDismissOnly()
            captureReplyToggleAnchor(for: parentCommentId)
            viewModel.send(.didTapToggleReplies(parentCommentId: parentCommentId))
        }
    }

    private func keyboardDismissOnly() {
        view.endEditing(true)
        let shouldResetReplyMode: Bool
        if case .reply = viewModel.state.composerMode {
            shouldResetReplyMode = true
        } else {
            shouldResetReplyMode = false
        }
        if shouldResetReplyMode {
            viewModel.send(.didTapCancelComposerMode)
        }
        ReviewDiscussionTrace.log("[ReviewDiscussionVC] keyboardDismissOnly clearReplyMode=\(shouldResetReplyMode)")
    }

    private func focusComposer(mode: ReviewDiscussionComposerMode) {
        ReviewDiscussionTrace.log("[ReviewDiscussionVC] focusComposer mode=\(mode.traceName)")
        rootView.focusComposer()
    }

    private func handleReplyEntry(for comment: ReviewComment, source: ReplyEntrySource = .direct) {
        guard comment.canReply else { return }

        if shouldNavigateReplyEntryToDetail {
            keyboardDismissOnly()
            onReplyDetailRequested?(comment, viewModel.state.review)
            return
        }

        activateReplyMode(for: comment, source: source)
    }

    private func activateReplyMode(
        for comment: ReviewComment,
        shouldFocusComposer: Bool = true,
        source: ReplyEntrySource = .direct
    ) {
        guard comment.canReply else { return }
        ReviewDiscussionTrace.log("[ReviewDiscussionVC] activateReplyMode commentId=\(comment.id)")
        switch source {
        case .direct:
            viewModel.send(.didTapReply(commentId: comment.id))
        case .cta:
            viewModel.send(.didTapReplyCTA(commentId: comment.id))
        }
        guard shouldFocusComposer else { return }
        focusComposer(mode: viewModel.state.composerMode)
    }

    private var shouldNavigateReplyEntryToDetail: Bool {
        viewModel.state.initialHighlightCommentId == nil && onReplyDetailRequested != nil
    }

    private func activateInitialReplyTargetIfNeeded() {
        guard hasViewAppeared,
              let targetCommentId = pendingInitialReplyTargetCommentId,
              let comment = viewModel.state.comments.first(where: { $0.id == targetCommentId }) else {
            return
        }

        pendingInitialReplyTargetCommentId = nil
        DispatchQueue.main.async { [weak self] in
            self?.activateReplyMode(
                for: comment,
                shouldFocusComposer: self?.shouldAutoFocusReplyComposerOnFirstAppearance == true
            )
        }
    }

    private func captureReplyToggleAnchor(for parentCommentId: String) {
        guard let row = dataSource.snapshot().itemIdentifiers.first(where: { row in
            if case .toggleReplies(let currentParentCommentId, _, _) = row {
                return currentParentCommentId == parentCommentId
            }
            return false
        }),
        let indexPath = dataSource.indexPath(for: row) else {
            pendingReplyToggleAnchor = nil
            return
        }

        let minY = rootView.tableView.rectForRow(at: indexPath).minY
        pendingReplyToggleAnchor = .init(parentCommentId: parentCommentId, minY: minY)
    }

    private func restoreReplyToggleAnchorIfNeeded() {
        guard let anchor = pendingReplyToggleAnchor else { return }
        pendingReplyToggleAnchor = nil
        rootView.tableView.layoutIfNeeded()

        guard let row = dataSource.snapshot().itemIdentifiers.first(where: { row in
            if case .toggleReplies(let currentParentCommentId, _, _) = row {
                return currentParentCommentId == anchor.parentCommentId
            }
            return false
        }),
        let indexPath = dataSource.indexPath(for: row) else {
            return
        }

        let updatedMinY = rootView.tableView.rectForRow(at: indexPath).minY
        let delta = updatedMinY - anchor.minY
        guard delta != 0 else { return }

        let minimumOffsetY = -rootView.tableView.adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            rootView.tableView.contentSize.height - rootView.tableView.bounds.height + rootView.tableView.adjustedContentInset.bottom
        )

        var contentOffset = rootView.tableView.contentOffset
        contentOffset.y = min(max(contentOffset.y + delta, minimumOffsetY), maximumOffsetY)
        rootView.tableView.setContentOffset(contentOffset, animated: false)
    }

    private func availableCommentActionKinds(for comment: ReviewComment) -> [ReviewCommentActionSheetViewController.Context.Action.Kind] {
        var kinds: [ReviewCommentActionSheetViewController.Context.Action.Kind] = []
        if comment.canReply {
            kinds.append(.reply)
        }
        if comment.canEdit {
            kinds.append(.edit)
        }
        if comment.canDelete {
            kinds.append(.delete)
        }
        if comment.canReport {
            kinds.append(.report)
        }
        return kinds
    }

    private func presentCommentActionSheet(for comment: ReviewComment) {
        let actionKinds = availableCommentActionKinds(for: comment)
        guard actionKinds.isEmpty == false else { return }

        keyboardDismissOnly()

        let model = ReviewCommentActionSheetModel(
            commentId: comment.id,
            reviewId: comment.reviewId,
            authorId: comment.author.id,
            authorNickname: comment.author.nickname,
            authorProfileImageUrl: comment.author.profileImageUrl,
            content: comment.content,
            createdAt: comment.createdAt,
            likeCount: comment.likeCount,
            isReply: comment.depth > 0,
            parentCommentId: comment.parentCommentId,
            isOwnedByCurrentUser: comment.isMine
        )

        let context = ReviewCommentActionSheetViewController.Context(
            title: model.title,
            metadata: model.metadata,
            avatarURL: model.avatarURL,
            avatarText: model.avatarText,
            avatarBackgroundColor: CommentActionAvatarPalette.color(for: comment.author.nickname),
            actions: actionKinds.map(makeCommentAction)
        )

        let viewController = ReviewCommentActionSheetViewController(context: context)
        viewController.onActionSelected = { [weak self] actionKind in
            self?.handleCommentActionSelection(actionKind, for: comment)
        }
        present(viewController, animated: false)
    }

    private func makeCommentAction(
        for kind: ReviewCommentActionSheetViewController.Context.Action.Kind
    ) -> ReviewCommentActionSheetViewController.Context.Action {
        switch kind {
        case .reply:
            return .init(
                kind: .reply,
                title: L10n.tr("Localizable", "review.comment.action.reply"),
                systemImageName: "arrowshape.turn.up.left",
                tintColor: .gpPrimary
            )
        case .edit:
            return .init(
                kind: .edit,
                title: L10n.Review.Action.edit,
                systemImageName: "pencil",
                tintColor: .gpTextPrimary
            )
        case .delete:
            return .init(
                kind: .delete,
                title: L10n.Review.Action.delete,
                systemImageName: "trash",
                tintColor: .gpCoral
            )
        case .report:
            return .init(
                kind: .report,
                title: L10n.Review.Action.report,
                systemImageName: "exclamationmark.bubble",
                tintColor: .gpCoral
            )
        }
    }

    private func handleCommentActionSelection(
        _ actionKind: ReviewCommentActionSheetViewController.Context.Action.Kind,
        for comment: ReviewComment
    ) {
        switch actionKind {
        case .reply:
            performAuthenticatedAction { [weak self] in
                self?.handleReplyEntry(for: comment)
            }
        case .edit:
            performAuthenticatedAction { [weak self] in
                self?.viewModel.send(.didTapEdit(commentId: comment.id))
                self?.focusComposer(mode: .edit(commentId: comment.id))
            }
        case .delete:
            performAuthenticatedAction { [weak self] in
                self?.presentCommentDeleteConfirmationAlert(for: comment)
            }
        case .report:
            performAuthenticatedAction(for: .moderation) { [weak self] in
                self?.presentCommentReportReasonSheet(for: comment)
            }
        }
    }

    private func presentCommentDeleteConfirmationAlert(for comment: ReviewComment) {
        let alertController = UIAlertController(
            title: L10n.tr("Localizable", "review.comment.alert.deleteTitle"),
            message: L10n.tr("Localizable", "review.comment.alert.deleteMessage"),
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alertController.addAction(UIAlertAction(title: L10n.Review.Button.delete, style: .destructive) { [weak self] _ in
            self?.viewModel.send(.didTapDelete(commentId: comment.id))
        })
        present(alertController, animated: true)
    }

    private func presentCommentReportReasonSheet(for comment: ReviewComment) {
        let alertController = UIAlertController(
            title: L10n.Review.Report.selectReason,
            message: L10n.Review.Report.message,
            preferredStyle: .actionSheet
        )

        ReportReason.allCases.forEach { reason in
            alertController.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in
                guard let self else { return }
                if reason.requiresDetailInput {
                    self.presentCommentOtherReasonAlert(for: comment)
                } else {
                    self.viewModel.report(commentId: comment.id, reason: reason, detail: nil)
                }
            })
        }

        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        present(alertController, animated: true)
    }

    private func presentCommentOtherReasonAlert(for comment: ReviewComment) {
        let alertController = UIAlertController(
            title: L10n.Review.Report.otherTitle,
            message: L10n.Review.Report.otherMessage,
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            textField.placeholder = L10n.Review.Report.otherPlaceholder
            textField.clearButtonMode = .whileEditing
        }
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alertController.addAction(UIAlertAction(title: L10n.Review.Report.submit, style: .destructive) { [weak self, weak alertController] _ in
            let detail = alertController?.textFields?.first?.text
            self?.viewModel.report(commentId: comment.id, reason: .other, detail: detail)
        })
        present(alertController, animated: true)
    }

    private func tapTarget(for item: Row) -> TableTapTarget {
        switch item {
        case .reviewHeaderCard:
            return .reviewHeaderCard
        case .discussionHeader:
            return .background
        case .emptyState:
            return .background
        case .comment(let commentId):
            return .commentCell(commentId)
        case .toggleReplies(let parentCommentId, _, _):
            return .toggleReplies(parentCommentId)
        }
    }

    private func tapTargetForBlankArea(at location: CGPoint) -> TableTapTarget {
        _ = location
        return .background
    }

    private func handleTableTap(at location: CGPoint) {
        if let indexPath = rootView.tableView.indexPathForRow(at: location),
           let item = dataSource.itemIdentifier(for: indexPath) {
            handleTapTarget(tapTarget(for: item, at: location, indexPath: indexPath))
            return
        }

        handleTapTarget(tapTargetForBlankArea(at: location))
    }

    private func tapTarget(for item: Row, at location: CGPoint, indexPath: IndexPath) -> TableTapTarget {
        switch item {
        case .reviewHeaderCard:
            guard let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewDiscussionHeaderCardCell else {
                return .background
            }
            let pointInCell = rootView.tableView.convert(location, to: cell)
            return cell.containsCard(at: pointInCell) ? .reviewHeaderCard : .background
        default:
            return tapTarget(for: item)
        }
    }

    private func hasControlAncestor(_ view: UIView?) -> Bool {
        var currentView = view
        while let view = currentView {
            if view is UIControl {
                return true
            }
            currentView = view.superview
        }
        return false
    }

#if DEBUG
    func debugHandleTableTap(at location: CGPoint) {
        handleTableTap(at: location)
    }

    func debugHandleNavigationBarTap() {
        keyboardDismissOnly()
    }
#endif
}

extension ReviewDiscussionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        handleTapTarget(tapTarget(for: item))
    }
}

extension ReviewDiscussionViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === navigationBarTapGestureRecognizer {
            return navigationController?.topViewController === self
        }

        guard gestureRecognizer === keyboardDismissTapGestureRecognizer else { return true }

        if hasControlAncestor(touch.view) {
            return false
        }

        let location = touch.location(in: rootView.tableView)
        guard let indexPath = rootView.tableView.indexPathForRow(at: location),
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return true
        }

        switch item {
        case .reviewHeaderCard:
            guard let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewDiscussionHeaderCardCell else {
                return true
            }
            let pointInCell = rootView.tableView.convert(location, to: cell)
            return !cell.containsCard(at: pointInCell)
        case .discussionHeader:
            return true
        case .emptyState, .comment, .toggleReplies:
            return false
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === navigationBarTapGestureRecognizer
    }
}

extension ReviewDiscussionViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        ReviewDiscussionTrace.log("[ReviewDiscussionVC] composerDidBeginEditing")
    }

    func textViewDidChange(_ textView: UITextView) {
        viewModel.send(.didChangeComposerText(textView.text))
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        ReviewDiscussionTrace.log("[ReviewDiscussionVC] composerDidEndEditing")
    }
}

private extension ReviewDiscussionComposerMode {
    var traceName: String {
        switch self {
        case .comment:
            return "comment"
        case .reply:
            return "reply"
        case .edit:
            return "edit"
        }
    }
}

private enum CommentActionAvatarPalette {
    private static let colors: [UIColor] = [
        UIColor(hex: "#6366F1"),
        UIColor(hex: "#3B5998"),
        UIColor(hex: "#2E8B57"),
        UIColor(hex: "#8B5CF6"),
        UIColor(hex: "#E85A4F"),
        UIColor(hex: "#FFB547")
    ]

    static func color(for seed: String) -> UIColor {
        colors[abs(seed.hashValue) % colors.count]
    }
}

private final class ReplyToggleCell: UITableViewCell {
    static let reuseIdentifier = "ReplyToggleCell"

    private let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpTextSecondary
        return label
    }()

    private let chevronView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .gpTextSecondary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(hiddenCount: Int, expanded: Bool) {
        titleLabel.text = expanded
            ? L10n.tr("Localizable", "review.comment.action.hideReplies")
            : L10n.tr("Localizable", "review.comment.action.moreReplies", hiddenCount)
        chevronView.image = UIImage(
            systemName: expanded ? "chevron.down" : "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        )
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        let rowStack = UIStackView(arrangedSubviews: [lineView, titleLabel, chevronView, UIView()])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 6
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            rowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 56),
            rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            lineView.widthAnchor.constraint(equalToConstant: 14),
            lineView.heightAnchor.constraint(equalToConstant: 1),
            chevronView.widthAnchor.constraint(equalToConstant: 12),
            chevronView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
}
