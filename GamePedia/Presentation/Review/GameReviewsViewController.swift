import UIKit

final class GameReviewsViewController: BaseViewController<GameReviewsRootView, GameReviewsState> {

    private let viewModel: GameReviewsViewModel
    private var reviews: [Review] = []
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?

    var onComposeRequested: ((Review?) -> Void)?
    var onReviewsChanged: (() -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

    init(rootView: GameReviewsRootView, viewModel: GameReviewsViewModel) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()
        setupTableView()
        bindViewModel()
        viewModel.loadReviews()
    }

    private func configureNavigationItem() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = viewModel.state.gameTitle
    }

    private func setupTableView() {
        rootView.tableView.register(GameReviewCell.self, forCellReuseIdentifier: GameReviewCell.reuseIdentifier)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }
        viewModel.onComposeRequested = { [weak self] review in
            self?.onComposeRequested?(review)
        }
        viewModel.onReviewsChanged = { [weak self] in
            self?.onReviewsChanged?()
        }

        render(viewModel.state)
    }

    override func render(_ state: GameReviewsState) {
        rootView.render(state)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: state.composeButtonTitle,
            style: .plain,
            target: self,
            action: #selector(didTapComposeButton)
        )

        if reviews.map(\.id) != state.reviews.map(\.id) {
            reviews = state.reviews
            rootView.tableView.reloadData()
        } else {
            reviews = state.reviews
        }

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            presentErrorAlert(message: errorMessage)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }

        if let successMessage = state.successMessage,
           successMessage != lastPresentedSuccessMessage {
            lastPresentedSuccessMessage = successMessage
            presentSuccessAlert(message: successMessage)
        } else if state.successMessage == nil {
            lastPresentedSuccessMessage = nil
        }
    }

    func reload() {
        viewModel.reload()
    }

    private func performAuthenticatedAction(
        for context: RestrictedActionContext,
        action: @escaping () -> Void
    ) {
        guard let onAuthenticationRequired else {
            action()
            return
        }

        onAuthenticationRequired(context, action)
    }

    @objc private func didTapComposeButton() {
        performAuthenticatedAction(for: .writeReview) { [weak self] in
            self?.viewModel.didTapCompose()
        }
    }

    private func presentReviewActionSheet(for review: Review) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if review.isMine {
            alertController.addAction(UIAlertAction(title: "리뷰 수정", style: .default) { [weak self] _ in
                self?.performAuthenticatedAction(for: .writeReview) { [weak self] in
                    self?.viewModel.didTapEdit(review: review)
                }
            })
            alertController.addAction(UIAlertAction(title: "리뷰 삭제", style: .destructive) { [weak self] _ in
                self?.performAuthenticatedAction(for: .writeReview) { [weak self] in
                    self?.presentDeleteConfirmationAlert(for: review)
                }
            })
        } else {
            alertController.addAction(UIAlertAction(title: "신고하기", style: .destructive) { [weak self] _ in
                self?.performAuthenticatedAction(for: .moderation) { [weak self] in
                    self?.presentReportReasonSheet(for: review)
                }
            })
            alertController.addAction(UIAlertAction(title: "차단하기", style: .destructive) { [weak self] _ in
                self?.performAuthenticatedAction(for: .moderation) { [weak self] in
                    self?.presentBlockConfirmationAlert(for: review)
                }
            })
        }
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alertController, animated: true)
    }

    private func presentReportReasonSheet(for review: Review) {
        let alertController = UIAlertController(
            title: "신고 사유를 선택해 주세요",
            message: "문제가 있는 콘텐츠를 발견하면 신고해 주세요.",
            preferredStyle: .actionSheet
        )

        ReportReason.allCases.forEach { reason in
            alertController.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in
                guard let self else { return }
                if reason.requiresDetailInput {
                    self.presentOtherReasonAlert(for: review)
                } else {
                    self.viewModel.report(review: review, reason: reason, detail: nil)
                }
            })
        }

        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alertController, animated: true)
    }

    private func presentOtherReasonAlert(for review: Review) {
        let alertController = UIAlertController(
            title: "기타 사유를 입력해 주세요",
            message: "선택 사항입니다. 필요한 경우 상세 내용을 입력해 주세요.",
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            textField.placeholder = "상세 내용을 입력해 주세요"
            textField.clearButtonMode = .whileEditing
        }
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "신고 접수", style: .destructive) { [weak self, weak alertController] _ in
            let detail = alertController?.textFields?.first?.text
            self?.viewModel.report(review: review, reason: .other, detail: detail)
        })
        present(alertController, animated: true)
    }

    private func presentBlockConfirmationAlert(for review: Review) {
        let alertController = UIAlertController(
            title: "이 사용자를 차단하시겠습니까?",
            message: "차단한 사용자의 콘텐츠는 더 이상 표시되지 않습니다.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "차단", style: .destructive) { [weak self] _ in
            self?.viewModel.block(review: review)
        })
        present(alertController, animated: true)
    }

    private func presentDeleteConfirmationAlert(for review: Review) {
        let alertController = UIAlertController(
            title: "리뷰를 삭제할까요?",
            message: "삭제한 리뷰는 복구할 수 없습니다.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.viewModel.delete(review: review)
        })
        present(alertController, animated: true)
    }

    private func presentErrorAlert(message: String) {
        let alertController = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
    }

    private func presentSuccessAlert(message: String) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.viewModel.clearSuccessMessage()
        })
        present(alertController, animated: true)
    }
}

extension GameReviewsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        reviews.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: GameReviewCell.reuseIdentifier,
            for: indexPath
        ) as! GameReviewCell
        let review = reviews[indexPath.row]
        cell.configure(with: review)
        cell.onMoreButtonTapped = { [weak self] in
            self?.presentReviewActionSheet(for: review)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
