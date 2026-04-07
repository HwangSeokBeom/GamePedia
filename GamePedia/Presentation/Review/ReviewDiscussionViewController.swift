import UIKit

final class ReviewDiscussionViewController: BaseViewController<ReviewDiscussionRootView, ReviewDiscussionState> {
    private enum Section: String {
        case reviewHeaderCard
        case discussionHeader
        case emptyState
        case comments
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

    private let viewModel: ReviewDiscussionViewModel
    private var dataSource: UITableViewDiffableDataSource<Section, Row>!
    private var commentById: [String: ReviewComment] = [:]
    private var lastRenderedSnapshotSignature: SnapshotSignature?
    private var currentReviewHeaderState: ReviewDiscussionHeaderState?
    private var currentDiscussionSectionState: ReviewDiscussionSectionState?
    private var currentSortMenu: UIMenu?
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
                }
                return cell
            case .discussionHeader:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReviewDiscussionSectionHeaderCell.reuseIdentifier, for: indexPath) as! ReviewDiscussionSectionHeaderCell
                if let sectionState = self.currentDiscussionSectionState {
                    cell.configure(with: sectionState, sortMenu: self.currentSortMenu)
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

        let commentRows = makeRows(from: state.comments, expandedParentCommentIds: state.expandedParentCommentIds)
        commentById = MappingSafety.dictionary(
            pairs: state.comments.map { ($0.id, $0) },
            logPrefix: "[CommentMapping]",
            keyName: "commentId",
            countLabel: "commentCount",
            screen: "ReviewDiscussionViewController.applySnapshotIfNeeded",
            mergePolicy: .keepFirst
        )
        let signature = makeSnapshotSignature(for: state, commentRows: commentRows)
        print(
            "[ReviewDiscussionSnapshot] reviewHeaderStateNil=\(state.reviewHeaderState == nil) contentState=\(state.discussionContentState) sections=\(signature.sections.map { $0.section.rawValue })"
        )
        guard signature != lastRenderedSnapshotSignature else { return }
        lastRenderedSnapshotSignature = signature

        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        signature.sections.forEach { section in
            snapshot.appendSections([section.section])
            snapshot.appendItems(section.rows, toSection: section.section)
        }
        dataSource.apply(snapshot, animatingDifferences: true)
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
        guard let indexPath = dataSource.indexPath(for: .comment(commentId)) else { return }
        rootView.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let cell = self.rootView.tableView.cellForRow(at: indexPath) as? ReviewCommentCell {
                cell.animateHighlight()
            }
        }
    }

    private func refreshVisibleRows(for state: ReviewDiscussionState) {
        print("[ReviewDiscussionRender] reviewHeaderStateNil=\(state.reviewHeaderState == nil) discussionSectionStateNil=\(state.discussionSectionState == nil)")

        if let headerState = state.reviewHeaderState,
           let indexPath = dataSource.indexPath(for: .reviewHeaderCard(headerState.review.id)),
           let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewDiscussionHeaderCardCell {
            cell.configure(with: headerState)
        }

        if let discussionSectionState = state.discussionSectionState,
           let indexPath = dataSource.indexPath(for: .discussionHeader(state.reviewId)),
           let cell = rootView.tableView.cellForRow(at: indexPath) as? ReviewDiscussionSectionHeaderCell {
            cell.configure(with: discussionSectionState, sortMenu: currentSortMenu)
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
            showsActions: !comment.isDeleted,
            canReply: comment.canReply,
            isReactionLoading: reactingCommentIds.contains(comment.id)
        ))
        cell.onReplyTapped = { [weak self] in
            self?.performAuthenticatedAction {
                self?.viewModel.send(.didTapReply(commentId: comment.id))
                self?.rootView.focusComposer()
            }
        }
        cell.onLikeTapped = { [weak self] in
            self?.performAuthenticatedAction {
                self?.viewModel.send(.didTapLike(commentId: comment.id))
            }
        }
        cell.onMoreTapped = { [weak self] in
            self?.presentActionSheet(for: comment)
        }
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

    private func presentActionSheet(for comment: ReviewComment) {
        let title = comment.isMine
            ? L10n.tr("Localizable", "review.comment.sheet.mineTitle")
            : L10n.tr("Localizable", "review.comment.sheet.otherTitle", comment.author.nickname)
        let metadata = L10n.tr("Localizable", "review.comment.sheet.meta", comment.formattedDate, comment.likeCount)

        var actions: [ReviewCommentActionSheetViewController.Context.Action] = [
            .init(kind: .reply, title: L10n.tr("Localizable", "review.comment.action.reply"), systemImageName: "message", tintColor: .gpTextPrimary)
        ]

        if comment.canEdit {
            actions.append(.init(kind: .edit, title: L10n.Review.Action.edit, systemImageName: "pencil", tintColor: .gpTextPrimary))
        }

        if comment.canDelete {
            actions.append(.init(kind: .delete, title: L10n.Review.Action.delete, systemImageName: "trash", tintColor: .gpCoral))
        }

        if comment.canReport {
            actions.append(.init(kind: .report, title: L10n.Review.Action.report, systemImageName: "flag", tintColor: .gpCoral))
        }

        let viewController = ReviewCommentActionSheetViewController(
            context: .init(
                title: title,
                metadata: metadata,
                avatarURL: comment.author.avatarURL,
                avatarText: String(comment.author.nickname.first ?? " "),
                avatarBackgroundColor: commentAvatarColor(for: comment.author.nickname),
                actions: actions
            )
        )
        viewController.onActionSelected = { [weak self] action in
            switch action {
            case .reply:
                self?.performAuthenticatedAction {
                    self?.viewModel.send(.didTapReply(commentId: comment.id))
                    self?.rootView.focusComposer()
                }
            case .edit:
                self?.performAuthenticatedAction {
                    self?.viewModel.send(.didTapEdit(commentId: comment.id))
                    self?.rootView.focusComposer()
                }
            case .delete:
                self?.performAuthenticatedAction {
                    self?.presentDeleteConfirmationAlert(for: comment)
                }
            case .report:
                self?.performAuthenticatedAction(for: .moderation) {
                    self?.presentReportReasonSheet(for: comment)
                }
            }
        }
        present(viewController, animated: false)
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

    @objc private func didTapEmptyStateAction() {
        rootView.focusComposer()
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
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .toggleReplies(let parentCommentId, _, _) = item {
            viewModel.send(.didTapToggleReplies(parentCommentId: parentCommentId))
        }
    }
}

extension ReviewDiscussionViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.send(.didChangeComposerText(textView.text))
    }
}

private extension ReviewDiscussionViewController {
    func commentAvatarColor(for seed: String) -> UIColor {
        let colors: [UIColor] = [
            UIColor(hex: "#6366F1"),
            UIColor(hex: "#3B5998"),
            UIColor(hex: "#2E8B57"),
            UIColor(hex: "#8B5CF6"),
            UIColor(hex: "#E85A4F"),
            UIColor(hex: "#FFB547")
        ]
        return colors[abs(seed.hashValue) % colors.count]
    }
}

private final class ReplyToggleCell: UITableViewCell {
    static let reuseIdentifier = "ReplyToggleCell"

    private let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpTextTertiary
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpPrimary
        return label
    }()

    private let chevronView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .gpPrimary
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
            rowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            lineView.widthAnchor.constraint(equalToConstant: 20),
            lineView.heightAnchor.constraint(equalToConstant: 1),
            chevronView.widthAnchor.constraint(equalToConstant: 12),
            chevronView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
}
