import UIKit

final class GameDetailRootView: UIView {

    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .gpBackground
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

    private let heroGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.locations = [0.55, 1.0]
        return layer
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let developerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
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
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        configuration.image = UIImage(systemName: "bookmark", withConfiguration: symbolConfiguration)
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = .systemFont(ofSize: 14, weight: .semibold)
            return updated
        }
        return UIButton(configuration: configuration)
    }()

    let writeReviewButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        configuration.title = L10n.Detail.Button.writeReview
        configuration.image = UIImage(systemName: "pencil", withConfiguration: symbolConfiguration)
        configuration.imagePadding = 8
        configuration.baseForegroundColor = .gpTextPrimary
        configuration.cornerStyle = .capsule
        configuration.background.backgroundColor = .gpSurfaceElevated
        configuration.background.strokeColor = .gpSeparator
        configuration.background.strokeWidth = 1
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = .systemFont(ofSize: 14, weight: .semibold)
            return updated
        }
        return UIButton(configuration: configuration)
    }()

    let steamReviewBannerView: SteamReviewLinkageBannerView = {
        let view = SteamReviewLinkageBannerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    let descriptionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Detail.Section.description
        label.font = .systemFont(ofSize: 18, weight: .bold)
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
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
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

    private let reviewSummaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let reviewTableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private var reviewTableHeightConstraint: NSLayoutConstraint!

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

        reviewSectionHeader.translatesAutoresizingMaskIntoConstraints = false
        reviewSectionHeader.configure(title: L10n.Detail.Section.userReviews)
        reviewSectionHeader.titleLabel.font = .systemFont(ofSize: 18, weight: .bold)

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

        let actionStackView = UIStackView(arrangedSubviews: [haveItButton, writeReviewButton])
        actionStackView.axis = .horizontal
        actionStackView.spacing = 12
        actionStackView.distribution = .fillEqually
        actionStackView.translatesAutoresizingMaskIntoConstraints = false

        let translationMetaStackView = UIStackView(arrangedSubviews: [translationIndicatorLabel, translationToggleButton, UIView()])
        translationMetaStackView.axis = .horizontal
        translationMetaStackView.alignment = .center
        translationMetaStackView.spacing = 8
        translationMetaStackView.translatesAutoresizingMaskIntoConstraints = false

        let contentStackView = UIStackView(arrangedSubviews: [
            titleRowStackView,
            statsView,
            actionStackView,
            steamReviewBannerView,
            descriptionTitleLabel,
            inlineNoticeLabel,
            translationMetaStackView,
            descriptionLabel,
            reviewSectionHeader,
            reviewSummaryLabel,
            reviewTableView
        ])
        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.setCustomSpacing(10, after: descriptionTitleLabel)
        contentStackView.setCustomSpacing(10, after: inlineNoticeLabel)
        contentStackView.setCustomSpacing(10, after: translationMetaStackView)
        contentStackView.setCustomSpacing(12, after: reviewSectionHeader)
        contentStackView.setCustomSpacing(12, after: reviewSummaryLabel)

        addSubview(scrollView)
        scrollView.addSubview(heroImageView)
        scrollView.addSubview(contentStackView)

        reviewTableHeightConstraint = reviewTableView.heightAnchor.constraint(equalToConstant: 0)
        reviewTableHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            heroImageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            heroImageView.heightAnchor.constraint(equalToConstant: 280),

            contentStackView.topAnchor.constraint(equalTo: heroImageView.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            
            heartButton.widthAnchor.constraint(equalToConstant: 40),
            heartButton.heightAnchor.constraint(equalToConstant: 40),
            translationIndicatorLabel.heightAnchor.constraint(equalToConstant: 20),

            statsView.heightAnchor.constraint(equalToConstant: 80),

            haveItButton.heightAnchor.constraint(equalToConstant: 44),
            writeReviewButton.heightAnchor.constraint(equalToConstant: 44)
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
        reviewSummaryLabel.text = state.reviewSummaryText
        reviewSectionHeader.seeMoreButton.isHidden = !state.shouldShowReviewSeeMore
        steamReviewBannerView.isHidden = !state.showSteamReviewLinkage
        print("[UI] rendered resolvedTitle:", state.title)
        print("[UI] rendered resolvedSummary:", state.summary)
        print(
            "[TranslationDisplay] " +
            "isShowingTranslated=\(state.isShowingTranslated) " +
            "hasTranslation=\(state.hasTranslation) " +
            "isTranslationAvailable=\(state.isTranslationAvailable)"
        )
    }

    func updateReviewTableHeight() {
        layoutIfNeeded()
        reviewTableHeightConstraint.constant = reviewTableView.contentSize.height
    }

    private func applyDynamicLayerColors() {
        heroGradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.gpHeroGradientEnd.resolvedCGColor(with: traitCollection)
        ]
        heartButton.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }
}
