import UIKit

final class GameDetailViewController: BaseViewController<GameDetailRootView, GameDetailState> {

    // MARK: Properties

    private let viewModel: GameDetailViewModel
    let gameId: Int
    private var previewReviews: [Review] = []

    // Set by the owning Coordinator before push.
    var onWriteReview: ((GameDetail, Review?) -> Void)?
    var onShowAllReviews: ((GameDetail) -> Void)?
    var onShare: ((GameDetail) -> Void)?

    // MARK: Init

    init(
        gameId: Int,
        viewModel: GameDetailViewModel = GameDetailViewModel()
    ) {
        self.gameId = gameId
        self.viewModel = viewModel
        super.init(rootView: GameDetailRootView())
        NavigationBarStyler.apply(.transparent, to: navigationItem)
        configureNavigationItem()
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        setupTableView()
        bindViewModel()
        viewModel.send(.viewDidLoad(gameId: gameId))
    }

    // MARK: Setup

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.title = nil
            let shareImage = UIImage(systemName: "square.and.arrow.up")?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: shareImage,
                style: .plain,
                target: self,
                action: #selector(didTapShare)
            )
        }
    }

    private func setupActions() {
        rootView.haveItButton.addTarget(self, action: #selector(didTapHaveIt), for: .touchUpInside)
        rootView.heartButton.addTarget(self, action: #selector(didTapHaveIt), for: .touchUpInside)
        rootView.writeReviewButton.addTarget(self, action: #selector(didTapWriteReview), for: .touchUpInside)
        rootView.reviewSectionHeader.seeMoreButton.addTarget(self, action: #selector(didTapSeeAllReviews), for: .touchUpInside)
    }

    private func setupTableView() {
        rootView.reviewTableView.dataSource = self
        rootView.reviewTableView.delegate = self
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }

        // Forward ViewModel navigation events to the Coordinator via public callbacks.
        viewModel.onWriteReview = { [weak self] game, existingReview in
            self?.onWriteReview?(game, existingReview)
        }

        viewModel.onShowAllReviews = { [weak self] game in
            self?.onShowAllReviews?(game)
        }

        viewModel.onShare = { [weak self] game in
            self?.onShare?(game)
        }
    }

    // MARK: Render

    override func render(_ state: GameDetailState) {
        rootView.render(state)

        if previewReviews != state.previewReviews {
            previewReviews = state.previewReviews
            rootView.reviewTableView.reloadData()
            rootView.updateReviewTableHeight()
        }

        let bookmarkSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        var haveItButtonConfiguration = rootView.haveItButton.configuration
        haveItButtonConfiguration?.title = state.isOwned ? "보유 중" : "찜하기"
        haveItButtonConfiguration?.image = UIImage(
            systemName: state.isOwned ? "bookmark.fill" : "bookmark",
            withConfiguration: bookmarkSymbolConfiguration
        )
        haveItButtonConfiguration?.baseBackgroundColor = state.isOwned ? .gpSurfaceElevated : .gpPrimary
        rootView.haveItButton.configuration = haveItButtonConfiguration

        var heartButtonConfiguration = rootView.heartButton.configuration
        heartButtonConfiguration?.image = UIImage(systemName: state.isOwned ? "heart.fill" : "heart")
        rootView.heartButton.configuration = heartButtonConfiguration

        var writeReviewButtonConfiguration = rootView.writeReviewButton.configuration
        writeReviewButtonConfiguration?.title = state.writeReviewButtonTitle
        rootView.writeReviewButton.configuration = writeReviewButtonConfiguration
    }

    // MARK: Public

    /// Called by the Coordinator's onReviewSubmitted callback to reload data.
    func reload() {
        viewModel.send(.viewDidLoad(gameId: gameId))
    }

    // MARK: Actions

    @objc private func didTapHaveIt() {
        viewModel.send(.didTapHaveIt)
    }

    @objc private func didTapWriteReview() {
        viewModel.send(.didTapWriteReview)
    }

    @objc private func didTapSeeAllReviews() {
        viewModel.send(.didTapSeeAllReviews)
    }

    @objc private func didTapShare() {
        viewModel.send(.didTapShare)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension GameDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        previewReviews.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ReviewCardCell.reuseId,
            for: indexPath
        ) as! ReviewCardCell
        cell.configure(with: previewReviews[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
