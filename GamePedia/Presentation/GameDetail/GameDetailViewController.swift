import UIKit

final class GameDetailViewController: BaseViewController<GameDetailRootView, GameDetailState> {

    // MARK: Properties

    private let viewModel: GameDetailViewModel
    let gameId: Int
    private var renderedPreviewReviews: [Review] = []
    private var lastPresentedErrorMessage: String?
    private var lastPresentedBlockingLoadErrorMessage: String?
    private lazy var translationHostController = TranslationHostContainerViewController { [weak self] results in
        self?.viewModel.send(.didReceiveTranslationResults(results))
    }

    // Set by the owning Coordinator before push.
    var onWriteReview: ((GameDetail, Review?) -> Void)?
    var onShowAllReviews: ((GameDetail) -> Void)?
    var onReviewSelected: ((GameDetail, Review) -> Void)?
    var onShare: ((GameDetail) -> Void)?
    var onAuthenticationRequired: ((RestrictedActionContext, @escaping () -> Void) -> Void)?

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
        setupTranslationHost()
        bindViewModel()
        viewModel.send(.viewDidLoad(gameId: gameId))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        rootView.updateReviewTableHeight()
        updateScrollInsets()
    }

    // MARK: Setup

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.title = nil
            let shareImage = UIImage(systemName: "square.and.arrow.up")?
                .withTintColor(.gpOnPrimary, renderingMode: .alwaysOriginal)
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
        rootView.myReviewNewButton.addTarget(self, action: #selector(didTapWriteReview), for: .touchUpInside)
        rootView.emptyStateView.actionButton.addTarget(self, action: #selector(didTapWriteReview), for: .touchUpInside)
        rootView.reviewSectionHeader.seeMoreButton.addTarget(self, action: #selector(didTapSeeAllReviews), for: .touchUpInside)
        rootView.translationToggleButton.addTarget(self, action: #selector(didTapTranslationToggle), for: .touchUpInside)
        rootView.steamReviewBannerView.onWriteReviewTapped = { [weak self] in
            self?.didTapWriteReview()
        }
        rootView.onEditMyReview = { [weak self] review in
            self?.didTapEditReview(review)
        }
    }

    private func setupTableView() {
        rootView.reviewTableView.dataSource = self
        rootView.reviewTableView.delegate = self
    }

    private func setupTranslationHost() {
        addChild(translationHostController)
        view.addSubview(translationHostController.view)
        translationHostController.view.translatesAutoresizingMaskIntoConstraints = false
        translationHostController.view.isHidden = true
        NSLayoutConstraint.activate([
            translationHostController.view.topAnchor.constraint(equalTo: view.topAnchor),
            translationHostController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            translationHostController.view.widthAnchor.constraint(equalToConstant: 0),
            translationHostController.view.heightAnchor.constraint(equalToConstant: 0)
        ])
        translationHostController.didMove(toParent: self)
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
        translationHostController.update(request: state.translationRequest)

        if renderedPreviewReviews != state.previewReviews {
            renderedPreviewReviews = state.previewReviews
            print(
                "[GameDetailPreview] render " +
                "fetchReviewsCount=\(state.reviews.count) " +
                "myReviewCount=\(state.myReviews.count) " +
                "communityCount=\(state.communityPreviewReviews.count) " +
                "finalRenderedCount=\(renderedPreviewReviews.count) " +
                "previewLimit=\(GameDetailState.reviewPreviewLimit)"
            )
            rootView.reviewTableView.reloadData()
            rootView.reviewTableView.layoutIfNeeded()
            rootView.updateReviewTableHeight()
            DispatchQueue.main.async { [weak self] in
                self?.rootView.updateReviewTableHeight()
            }
        }

        let bookmarkSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        var haveItButtonConfiguration = rootView.haveItButton.configuration
        haveItButtonConfiguration?.title = state.isFavorite ? L10n.Detail.Button.favorited : L10n.Detail.Button.favorite
        haveItButtonConfiguration?.image = UIImage(
            systemName: state.isFavorite ? "bookmark.fill" : "bookmark",
            withConfiguration: bookmarkSymbolConfiguration
        )
        haveItButtonConfiguration?.baseBackgroundColor = state.isFavorite ? .gpSurfaceElevated : .gpPrimary
        rootView.haveItButton.configuration = haveItButtonConfiguration
        rootView.haveItButton.isEnabled = !state.isFavoriteLoading
        rootView.haveItButton.accessibilityLabel = haveItButtonConfiguration?.title

        var heartButtonConfiguration = rootView.heartButton.configuration
        heartButtonConfiguration?.image = UIImage(systemName: state.isFavorite ? "heart.fill" : "heart")
        rootView.heartButton.configuration = heartButtonConfiguration
        rootView.heartButton.isEnabled = !state.isFavoriteLoading
        rootView.heartButton.accessibilityLabel = haveItButtonConfiguration?.title

        var writeReviewButtonConfiguration = rootView.writeReviewButton.configuration
        writeReviewButtonConfiguration?.title = state.writeReviewButtonTitle
        rootView.writeReviewButton.configuration = writeReviewButtonConfiguration

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            let alert = UIAlertController(title: L10n.Common.Error.title, message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
            present(alert, animated: true)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }

        if let errorMessage = state.blockingLoadErrorMessage,
           errorMessage != lastPresentedBlockingLoadErrorMessage,
           !state.hasRenderableContent {
            lastPresentedBlockingLoadErrorMessage = errorMessage
            let alert = UIAlertController(title: L10n.Common.Error.title, message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .default))
            present(alert, animated: true)
        } else if state.blockingLoadErrorMessage == nil {
            lastPresentedBlockingLoadErrorMessage = nil
        }
    }

    private func updateScrollInsets() {
        let bottomInset = resolvedBottomScrollInset()
        let currentVerticalIndicatorInsets = rootView.scrollView.verticalScrollIndicatorInsets
        guard rootView.scrollView.contentInset.bottom != bottomInset
                || currentVerticalIndicatorInsets.bottom != bottomInset else {
            return
        }

        rootView.scrollView.contentInset.bottom = bottomInset
        var updatedVerticalIndicatorInsets = currentVerticalIndicatorInsets
        updatedVerticalIndicatorInsets.bottom = bottomInset
        rootView.scrollView.verticalScrollIndicatorInsets = updatedVerticalIndicatorInsets
    }

    private func resolvedBottomScrollInset() -> CGFloat {
        let safeAreaBottom = view.safeAreaInsets.bottom
        let tabBarOverlap = visibleTabBarOverlapHeight()
        let breathingRoom: CGFloat = 28
        return max(safeAreaBottom, tabBarOverlap) + breathingRoom
    }

    private func visibleTabBarOverlapHeight() -> CGFloat {
        guard let tabBar = tabBarController?.tabBar,
              !tabBar.isHidden,
              tabBar.alpha > 0.01,
              let containerView = tabBar.superview else {
            return 0
        }

        let convertedFrame = view.convert(tabBar.frame, from: containerView)
        let overlap = view.bounds.intersection(convertedFrame)
        guard !overlap.isNull else { return 0 }
        return overlap.height
    }

    // MARK: Public

    /// Called by the Coordinator's onReviewSubmitted callback to reload data.
    func reload() {
        viewModel.send(.viewDidLoad(gameId: gameId))
    }

    // MARK: Actions

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

    @objc private func didTapHaveIt() {
        performAuthenticatedAction(for: .favoriteGame) { [weak self] in
            self?.viewModel.send(.didTapHaveIt)
        }
    }

    @objc private func didTapWriteReview() {
        performAuthenticatedAction(for: .writeReview) { [weak self] in
            self?.viewModel.send(.didTapWriteReview)
        }
    }

    private func didTapEditReview(_ review: Review) {
        performAuthenticatedAction(for: .writeReview) { [weak self] in
            guard
                let self,
                let game = self.viewModel.state.game
            else { return }

            self.onWriteReview?(game, review)
        }
    }

    @objc private func didTapSeeAllReviews() {
        performAuthenticatedAction(for: .viewReviews) { [weak self] in
            self?.viewModel.send(.didTapSeeAllReviews)
        }
    }

    @objc private func didTapShare() {
        viewModel.send(.didTapShare)
    }

    @objc private func didTapTranslationToggle() {
        viewModel.send(.didTapTranslationToggle)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension GameDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        renderedPreviewReviews.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ReviewCardCell.reuseId,
            for: indexPath
        ) as! ReviewCardCell
        let review = renderedPreviewReviews[indexPath.row]
        cell.configure(with: review)
        cell.onLikeTapped = { [weak self] in
            self?.performAuthenticatedAction(for: .viewReviews) { [weak self] in
                self?.viewModel.send(.didTapReviewLike(reviewId: review.id))
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard renderedPreviewReviews.indices.contains(indexPath.row),
              let game = viewModel.state.game else { return }
        onReviewSelected?(game, renderedPreviewReviews[indexPath.row])
    }
}
