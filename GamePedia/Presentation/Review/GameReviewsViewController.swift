import UIKit

final class GameReviewsViewController: BaseViewController<GameReviewsRootView, GameReviewsState> {

    private let viewModel: GameReviewsViewModel
    private var reviews: [Review] = []
    private var lastPresentedErrorMessage: String?

    var onComposeRequested: ((Review?) -> Void)?
    var onReviewsChanged: (() -> Void)?

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
        }
    }

    func reload() {
        viewModel.reload()
    }

    @objc private func didTapComposeButton() {
        viewModel.didTapCompose()
    }

    private func presentReviewActionSheet(for review: Review) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "리뷰 수정", style: .default) { [weak self] _ in
            self?.viewModel.didTapEdit(review: review)
        })
        alertController.addAction(UIAlertAction(title: "리뷰 삭제", style: .destructive) { [weak self] _ in
            self?.presentDeleteConfirmationAlert(for: review)
        })
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
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
