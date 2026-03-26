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
        configuration.title = "찜하기"
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
        configuration.title = "리뷰 작성"
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

    let descriptionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "게임 소개"
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        reviewSectionHeader.configure(title: "유저 리뷰")
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

        let contentStackView = UIStackView(arrangedSubviews: [
            titleRowStackView,
            statsView,
            actionStackView,
            descriptionTitleLabel,
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
        reviewSummaryLabel.text = state.reviewSummaryText
        reviewSectionHeader.seeMoreButton.isHidden = !state.shouldShowReviewSeeMore
        print("[UI] rendered resolvedTitle:", state.title)
        print("[UI] rendered resolvedSummary:", state.summary)
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
