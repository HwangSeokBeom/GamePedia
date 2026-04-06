import UIKit

final class ReviewDiscussionViewController: BaseViewController<ReviewDiscussionRootView, ReviewDiscussionState> {
    private enum Section {
        case main
    }

    private enum Row: Hashable {
        case comment(String)
        case toggleReplies(parentCommentId: String, hiddenCount: Int, expanded: Bool)
    }

    private let viewModel: ReviewDiscussionViewModel
    private var dataSource: UITableViewDiffableDataSource<Section, Row>!
    private var commentById: [String: ReviewComment] = [:]
    private var lastRenderedRows: [Row] = []
    private var lastHighlightToken: Int = 0

    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    init(rootView: ReviewDiscussionRootView, viewModel: ReviewDiscussionViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        setupTableView()
        setupComposer()
        setupKeyboardObservers()
        bindViewModel()
        viewModel.send(.viewDidLoad)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func render(_ state: ReviewDiscussionState) {
        navigationItem.title = state.navigationTitle
        rootView.render(state)
        applyRowsIfNeeded(for: state)

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
    }

    private func setupTableView() {
        dataSource = UITableViewDiffableDataSource<Section, Row>(tableView: rootView.tableView) { [weak self] tableView, indexPath, row in
            guard let self else { return UITableViewCell() }
            switch row {
            case .comment(let commentId):
                let cell = tableView.dequeueReusableCell(withIdentifier: ReviewCommentCell.reuseIdentifier, for: indexPath) as! ReviewCommentCell
                guard let comment = self.commentById[commentId] else { return cell }
                let isSelfReply = comment.depth == 1 && comment.isMine && (self.commentById[comment.parentCommentId ?? ""]?.author.id == comment.author.id)
                let likeCountText = comment.likeCount > 0 ? String(comment.likeCount) : nil
                let dislikeCountText = comment.dislikeCount > 0 ? String(comment.dislikeCount) : nil
                cell.configure(with: .init(
                    id: comment.id,
                    authorName: comment.author.nickname,
                    authorAvatarURL: comment.author.avatarURL,
                    bodyText: comment.content,
                    dateText: comment.formattedDate,
                    depth: comment.depth,
                    isMine: comment.isMine,
                    isSelfReply: isSelfReply,
                    isReviewAuthor: comment.isReviewAuthor,
                    isDeleted: comment.isDeleted,
                    likeCountText: likeCountText,
                    dislikeCountText: dislikeCountText,
                    myReaction: comment.myReaction,
                    replyButtonTitle: L10n.tr("Localizable", "review.comment.action.reply"),
                    showsActions: !comment.isDeleted,
                    isReactionLoading: self.viewModel.state.reactingCommentIds.contains(comment.id)
                ))
                cell.onReplyTapped = { [weak self] in
                    self?.performAuthenticatedAction {
                        self?.viewModel.send(.didTapReply(commentId: comment.id))
                    }
                }
                cell.onLikeTapped = { [weak self] in
                    self?.performAuthenticatedAction {
                        self?.viewModel.send(.didTapLike(commentId: comment.id))
                    }
                }
                cell.onDislikeTapped = { [weak self] in
                    self?.performAuthenticatedAction {
                        self?.viewModel.send(.didTapDislike(commentId: comment.id))
                    }
                }
                cell.onMoreTapped = { [weak self] in
                    self?.presentActionSheet(for: comment)
                }
                return cell
            case .toggleReplies(_, let hiddenCount, let expanded):
                let cell = UITableViewCell(style: .default, reuseIdentifier: "toggleReplies")
                var configuration = UIListContentConfiguration.valueCell()
                configuration.text = expanded
                    ? L10n.tr("Localizable", "review.comment.action.hideReplies")
                    : L10n.tr("Localizable", "review.comment.action.moreReplies", hiddenCount)
                configuration.textProperties.font = .systemFont(ofSize: 13, weight: .semibold)
                configuration.textProperties.color = .gpPrimary
                cell.contentConfiguration = configuration
                cell.backgroundColor = .clear
                cell.selectionStyle = .none
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

    private func applyRowsIfNeeded(for state: ReviewDiscussionState) {
        let rows = makeRows(from: state.comments, expandedParentCommentIds: state.expandedParentCommentIds)
        commentById = Dictionary(uniqueKeysWithValues: state.comments.map { ($0.id, $0) })
        guard rows != lastRenderedRows else { return }
        lastRenderedRows = rows

        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        snapshot.appendSections([.main])
        snapshot.appendItems(rows, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func makeRows(from comments: [ReviewComment], expandedParentCommentIds: Set<String>) -> [Row] {
        let topLevelComments = comments.filter { $0.parentCommentId == nil }
        let repliesByParentId = Dictionary(
            grouping: comments.filter { $0.parentCommentId != nil },
            by: { $0.parentCommentId ?? "" }
        )
        let previewReplyLimit = 2
        var rows: [Row] = []

        for comment in topLevelComments {
            rows.append(.comment(comment.id))
            let replies = (repliesByParentId[comment.id] ?? []).sorted { $0.createdAt < $1.createdAt }
            guard !replies.isEmpty else { continue }

            let isExpanded = expandedParentCommentIds.contains(comment.id)
            let visibleReplies = isExpanded ? replies : Array(replies.prefix(previewReplyLimit))
            rows.append(contentsOf: visibleReplies.map { .comment($0.id) })

            if replies.count > previewReplyLimit || isExpanded {
                rows.append(.toggleReplies(
                    parentCommentId: comment.id,
                    hiddenCount: max(0, replies.count - visibleReplies.count),
                    expanded: isExpanded
                ))
            }
        }

        return rows
    }

    private func highlightCommentIfNeeded(commentId: String) {
        guard let row = lastRenderedRows.firstIndex(of: .comment(commentId)) else { return }
        let indexPath = IndexPath(row: row, section: 0)
        rootView.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let cell = self.rootView.tableView.cellForRow(at: indexPath) as? ReviewCommentCell {
                cell.animateHighlight()
            }
        }
    }

    private func performAuthenticatedAction(_ action: @escaping () -> Void) {
        guard let onAuthenticationRequired else {
            action()
            return
        }
        onAuthenticationRequired(.viewReviews, action)
    }

    private func presentActionSheet(for comment: ReviewComment) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if comment.canEdit {
            alertController.addAction(UIAlertAction(title: L10n.Review.Action.edit, style: .default) { [weak self] _ in
                self?.performAuthenticatedAction {
                    self?.viewModel.send(.didTapEdit(commentId: comment.id))
                }
            })
        }
        if comment.canDelete {
            alertController.addAction(UIAlertAction(title: L10n.Review.Action.delete, style: .destructive) { [weak self] _ in
                self?.performAuthenticatedAction {
                    self?.presentDeleteConfirmationAlert(for: comment)
                }
            })
        }
        if comment.canReport {
            alertController.addAction(UIAlertAction(title: L10n.Review.Action.report, style: .destructive) { [weak self] _ in
                self?.performAuthenticatedAction {
                    self?.presentReportReasonSheet(for: comment)
                }
            })
        }
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        present(alertController, animated: true)
    }

    private func presentDeleteConfirmationAlert(for comment: ReviewComment) {
        let alertController = UIAlertController(
            title: L10n.Review.Alert.deleteTitle,
            message: L10n.Review.Alert.deleteMessage,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        alertController.addAction(UIAlertAction(title: L10n.Review.Button.delete, style: .destructive) { [weak self] _ in
            self?.viewModel.send(.didTapDelete(commentId: comment.id))
        })
        present(alertController, animated: true)
    }

    private func presentReportReasonSheet(for comment: ReviewComment) {
        let alertController = UIAlertController(
            title: L10n.Review.Report.selectReason,
            message: L10n.Review.Report.message,
            preferredStyle: .actionSheet
        )

        ReportReason.allCases.forEach { reason in
            alertController.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in
                guard let self else { return }
                if reason.requiresDetailInput {
                    self.presentOtherReasonAlert(for: comment)
                } else {
                    self.viewModel.report(commentId: comment.id, reason: reason, detail: nil)
                }
            })
        }

        alertController.addAction(UIAlertAction(title: L10n.Common.Button.cancel, style: .cancel))
        present(alertController, animated: true)
    }

    private func presentOtherReasonAlert(for comment: ReviewComment) {
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

    @objc private func didTapRetry() {
        viewModel.send(.didTapRetry)
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
}

extension ReviewDiscussionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 0, lastRenderedRows.indices.contains(indexPath.row) else { return }
        if case .toggleReplies(let parentCommentId, _, _) = lastRenderedRows[indexPath.row] {
            viewModel.send(.didTapToggleReplies(parentCommentId: parentCommentId))
        }
    }
}

extension ReviewDiscussionViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.send(.didChangeComposerText(textView.text))
    }
}
