import UIKit

final class GameDetailRootView: UIView {
    private let heroGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.locations = [0.5, 1.0]
        return layer
    }()

    private let myReviewCountBadgeView = UIView()
    private let myReviewCountBadgeLabel = UILabel()
    private let myReviewCardsStackView = UIStackView()
    private let contentStackView = UIStackView()
    private let descriptionSectionStackView = UIStackView()
    private let myReviewSectionStackView = UIStackView()
    private let communitySectionStackView = UIStackView()
    private let actionStackView = UIStackView()
    private let translationMetaStackView = UIStackView()
    private var heroHeightConstraint: NSLayoutConstraint!
    var onEditMyReview: ((Review) -> Void)?

    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .gpBackground
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    let heroImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .gpSerif(ofSize: 22, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let developerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let heartButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "heart")
        configuration.baseForegroundColor = .gpRed
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        button.backgroundColor = .gpSurface
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let statsView: GameStatsView = {
        let statsView = GameStatsView()
        statsView.translatesAutoresizingMaskIntoConstraints = false
        return statsView
    }()

    let haveItButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.Detail.Button.favorite
        configuration.image = UIImage(
            systemName: "bookmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 14, weight: .semibold)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let writeReviewButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.Detail.Button.writeReview
        configuration.image = UIImage(
            systemName: "square.and.pencil",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        configuration.imagePadding = 8
        configuration.baseForegroundColor = .gpTextPrimary
        configuration.cornerStyle = .capsule
        configuration.background.backgroundColor = .gpSurfaceElevated
        configuration.background.strokeColor = .gpSeparator
        configuration.background.strokeWidth = 1
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 14, weight: .semibold)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let myReviewNewButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.tr("Localizable", "detail.button.writeAnotherReview")
        configuration.image = UIImage(
            systemName: "plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )
        configuration.imagePadding = 4
        configuration.baseBackgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        configuration.baseForegroundColor = .gpPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 12, weight: .semibold)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let emptyStateView = MyReviewEmptyStateView()

    let steamReviewBannerView: SteamReviewLinkageBannerView = {
        let view = SteamReviewLinkageBannerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    let descriptionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Detail.Section.description
        label.font = .gpSerif(ofSize: 18, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let inlineNoticeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.backgroundColor = .gpSurfaceElevated
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.numberOfLines = 0
        label.textAlignment = .natural
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let translationIndicatorLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Translation.Banner.machineTranslated
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpPrimary
        label.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.12)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    let translationToggleButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.Translation.Action.showOriginal
        configuration.baseForegroundColor = .gpPrimary
        configuration.contentInsets = .zero
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 12, weight: .semibold)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let reviewSectionHeader = SectionHeaderView()

    let reviewTableView: UITableView = {
        let tableView = SelfSizingTableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 108
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let myReviewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .gpSerif(ofSize: 18, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.text = L10n.tr("Localizable", "detail.section.myRecords")
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyDynamicLayerColors()
    }

    private func setup() {
        backgroundColor = .gpBackground
        reviewTableView.register(ReviewCardCell.self, forCellReuseIdentifier: ReviewCardCell.reuseId)

        myReviewCountBadgeView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        myReviewCountBadgeView.layer.cornerRadius = 12
        myReviewCountBadgeView.layer.cornerCurve = .continuous
        myReviewCountBadgeView.translatesAutoresizingMaskIntoConstraints = false
        myReviewCountBadgeView.isHidden = true

        myReviewCountBadgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        myReviewCountBadgeLabel.textColor = .gpPrimary
        myReviewCountBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        myReviewCountBadgeView.addSubview(myReviewCountBadgeLabel)

        reviewSectionHeader.translatesAutoresizingMaskIntoConstraints = false
        reviewSectionHeader.configure(title: L10n.Detail.Section.userReviews)
        reviewSectionHeader.titleLabel.font = .gpSerif(ofSize: 18, weight: .semibold)
        var seeMoreConfiguration = reviewSectionHeader.seeMoreButton.configuration
        seeMoreConfiguration?.title = L10n.tr("Localizable", "common.button.viewAll")
        reviewSectionHeader.seeMoreButton.configuration = seeMoreConfiguration

        heroImageView.layer.addSublayer(heroGradientLayer)
        applyDynamicLayerColors()

        let titleInfoStackView = UIStackView(arrangedSubviews: [titleLabel, developerLabel])
        titleInfoStackView.axis = .vertical
        titleInfoStackView.spacing = 4

        let titleRowStackView = UIStackView(arrangedSubviews: [titleInfoStackView, heartButton])
        titleRowStackView.axis = .horizontal
        titleRowStackView.alignment = .top
        titleRowStackView.spacing = 12
        titleRowStackView.translatesAutoresizingMaskIntoConstraints = false

        actionStackView.axis = .horizontal
        actionStackView.spacing = 12
        actionStackView.distribution = .fillEqually
        actionStackView.translatesAutoresizingMaskIntoConstraints = false
        actionStackView.addArrangedSubview(haveItButton)
        actionStackView.addArrangedSubview(writeReviewButton)

        translationMetaStackView.axis = .horizontal
        translationMetaStackView.alignment = .center
        translationMetaStackView.spacing = 8
        translationMetaStackView.translatesAutoresizingMaskIntoConstraints = false
        translationMetaStackView.addArrangedSubview(translationIndicatorLabel)
        translationMetaStackView.addArrangedSubview(translationToggleButton)
        translationMetaStackView.addArrangedSubview(UIView())

        descriptionSectionStackView.axis = .vertical
        descriptionSectionStackView.spacing = 10
        descriptionSectionStackView.addArrangedSubview(descriptionTitleLabel)
        descriptionSectionStackView.addArrangedSubview(inlineNoticeLabel)
        descriptionSectionStackView.addArrangedSubview(translationMetaStackView)
        descriptionSectionStackView.addArrangedSubview(descriptionLabel)

        let myReviewHeaderLeadingStackView = UIStackView(arrangedSubviews: [myReviewTitleLabel, myReviewCountBadgeView])
        myReviewHeaderLeadingStackView.axis = .horizontal
        myReviewHeaderLeadingStackView.alignment = .center
        myReviewHeaderLeadingStackView.spacing = 8

        let myReviewHeaderStackView = UIStackView(arrangedSubviews: [myReviewHeaderLeadingStackView, UIView(), myReviewNewButton])
        myReviewHeaderStackView.axis = .horizontal
        myReviewHeaderStackView.alignment = .center

        myReviewCardsStackView.axis = .vertical
        myReviewCardsStackView.spacing = 14

        myReviewSectionStackView.axis = .vertical
        myReviewSectionStackView.spacing = 16
        myReviewSectionStackView.addArrangedSubview(myReviewHeaderStackView)
        myReviewSectionStackView.addArrangedSubview(emptyStateView)
        myReviewSectionStackView.addArrangedSubview(myReviewCardsStackView)

        communitySectionStackView.axis = .vertical
        communitySectionStackView.spacing = 12
        communitySectionStackView.addArrangedSubview(reviewSectionHeader)
        communitySectionStackView.addArrangedSubview(reviewTableView)

        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(titleRowStackView)
        contentStackView.addArrangedSubview(statsView)
        contentStackView.addArrangedSubview(actionStackView)
        contentStackView.addArrangedSubview(steamReviewBannerView)
        contentStackView.addArrangedSubview(descriptionSectionStackView)
        contentStackView.addArrangedSubview(myReviewSectionStackView)
        contentStackView.addArrangedSubview(communitySectionStackView)

        addSubview(scrollView)
        scrollView.addSubview(heroImageView)
        scrollView.addSubview(contentStackView)

        heroHeightConstraint = heroImageView.heightAnchor.constraint(equalToConstant: 240)
        heroHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            heroImageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),

            contentStackView.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: 0),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            heartButton.widthAnchor.constraint(equalToConstant: 40),
            heartButton.heightAnchor.constraint(equalToConstant: 40),
            translationIndicatorLabel.heightAnchor.constraint(equalToConstant: 20),

            statsView.heightAnchor.constraint(equalToConstant: 72),
            haveItButton.heightAnchor.constraint(equalToConstant: 44),
            writeReviewButton.heightAnchor.constraint(equalToConstant: 44),
            myReviewNewButton.heightAnchor.constraint(equalToConstant: 32),

            myReviewCountBadgeLabel.topAnchor.constraint(equalTo: myReviewCountBadgeView.topAnchor, constant: 4),
            myReviewCountBadgeLabel.leadingAnchor.constraint(equalTo: myReviewCountBadgeView.leadingAnchor, constant: 10),
            myReviewCountBadgeLabel.trailingAnchor.constraint(equalTo: myReviewCountBadgeView.trailingAnchor, constant: -10),
            myReviewCountBadgeLabel.bottomAnchor.constraint(equalTo: myReviewCountBadgeView.bottomAnchor, constant: -4)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        heroGradientLayer.frame = heroImageView.bounds
    }

    func render(_ state: GameDetailState) {
        guard let game = state.game else { return }

        heroImageView.loadImage(url: game.heroImageURL)
        titleLabel.text = state.title
        developerLabel.text = game.developerLine
        statsView.configure(game: game)
        descriptionLabel.text = state.summary
        inlineNoticeLabel.text = state.inlineNoticeMessage
        inlineNoticeLabel.isHidden = state.inlineNoticeMessage == nil
        translationIndicatorLabel.isHidden = !state.isTranslated
        translationToggleButton.isHidden = !state.hasTranslation
        var translationToggleConfiguration = translationToggleButton.configuration
        translationToggleConfiguration?.title = state.translationToggleTitle
        translationToggleButton.configuration = translationToggleConfiguration
        steamReviewBannerView.isHidden = !state.showSteamReviewLinkage

        heroHeightConstraint.constant = state.hasMyReviews ? 220 : 240
        writeReviewButton.isHidden = state.hasMyReviews
        myReviewNewButton.isHidden = !state.hasMyReviews

        let myReviews = Array(state.myReviews.prefix(GameDetailState.reviewPreviewLimit))
        emptyStateView.isHidden = !myReviews.isEmpty
        myReviewCardsStackView.isHidden = myReviews.isEmpty
        myReviewCountBadgeView.isHidden = myReviews.isEmpty
        myReviewCountBadgeLabel.text = String(state.myReviews.count)
        rebuildMyReviewCards(with: myReviews)

        reviewSectionHeader.isHidden = state.previewReviews.isEmpty
        reviewTableView.isHidden = state.previewReviews.isEmpty
        reviewSectionHeader.seeMoreButton.isHidden = !state.shouldShowReviewSeeMore
    }

    func updateReviewTableHeight() {
        reviewTableView.layoutIfNeeded()
        layoutIfNeeded()
        reviewTableView.invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func rebuildMyReviewCards(with reviews: [Review]) {
        myReviewCardsStackView.arrangedSubviews.forEach { view in
            myReviewCardsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        reviews.forEach { review in
            let cardView = MyReviewCardView()
            cardView.configure(with: review)
            cardView.onEditTapped = { [weak self] in
                self?.onEditMyReview?(review)
            }
            myReviewCardsStackView.addArrangedSubview(cardView)
        }
    }

    private func applyDynamicLayerColors() {
        heroGradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.gpHeroGradientEnd.resolvedCGColor(with: traitCollection)
        ]
        heartButton.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }
}

private final class SelfSizingTableView: UITableView {
    private var heightConstraint: NSLayoutConstraint?

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        configureHeightConstraintIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHeightConstraintIfNeeded()
    }

    override var contentSize: CGSize {
        didSet {
            guard oldValue != contentSize else { return }
            updateHeightConstraint()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: max(1, contentSize.height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeightConstraint()
    }

    private func configureHeightConstraintIfNeeded() {
        guard heightConstraint == nil else { return }
        let constraint = heightAnchor.constraint(equalToConstant: 1)
        constraint.priority = .required
        constraint.isActive = true
        heightConstraint = constraint
    }

    private func updateHeightConstraint() {
        heightConstraint?.constant = max(1, contentSize.height)
    }
}
