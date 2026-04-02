import UIKit

final class SteamFallbackGameDetailRootView: UIView {

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .gpBackground
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.layer.cornerRadius = 20
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let sourceBadgeContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.92)
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let sourceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpOnPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let playtimeLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Detail.Stats.playtime
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let playtimeValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Detail.Section.description
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let noteContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let noteLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.text = L10n.Detail.Fallback.note
        label.translatesAutoresizingMaskIntoConstraints = false
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

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func render(_ state: SteamFallbackGameDetailViewState) {
        titleLabel.text = state.title
        sourceLabel.text = state.sourceLabelText
        metadataLabel.text = state.metadataText
        descriptionLabel.text = state.descriptionText
        playtimeValueLabel.text = state.playtimeValueText
        let hasPlaytime = state.playtimeValueText != nil
        playtimeLabel.isHidden = !hasPlaytime
        playtimeValueLabel.isHidden = !hasPlaytime
        coverImageView.loadImage(
            url: state.coverImageURL,
            fallbackURLs: state.fallbackCoverImageURLs,
            placeholder: .gpGameCoverPlaceholder,
            logContext: "SteamFallbackDetail.\(state.externalGameId)"
        )
    }

    func prepareForReuse() {
        coverImageView.cancelLoad()
    }

    private func setup() {
        backgroundColor = .gpBackground

        addSubview(scrollView)
        scrollView.addSubview(contentView)

        let contentStackView = UIStackView(arrangedSubviews: [
            sourceBadgeContainerView,
            titleLabel,
            metadataLabel,
            playtimeLabel,
            playtimeValueLabel,
            descriptionTitleLabel,
            descriptionLabel,
            noteContainerView
        ])
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 12
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(coverImageView)
        contentView.addSubview(contentStackView)
        sourceBadgeContainerView.addSubview(sourceLabel)
        noteContainerView.addSubview(noteLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            coverImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            coverImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            coverImageView.heightAnchor.constraint(equalTo: coverImageView.widthAnchor, multiplier: 0.62),

            contentStackView.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            sourceLabel.topAnchor.constraint(equalTo: sourceBadgeContainerView.topAnchor, constant: 6),
            sourceLabel.leadingAnchor.constraint(equalTo: sourceBadgeContainerView.leadingAnchor, constant: 10),
            sourceLabel.trailingAnchor.constraint(equalTo: sourceBadgeContainerView.trailingAnchor, constant: -10),
            sourceLabel.bottomAnchor.constraint(equalTo: sourceBadgeContainerView.bottomAnchor, constant: -6),

            noteLabel.topAnchor.constraint(equalTo: noteContainerView.topAnchor, constant: 14),
            noteLabel.leadingAnchor.constraint(equalTo: noteContainerView.leadingAnchor, constant: 14),
            noteLabel.trailingAnchor.constraint(equalTo: noteContainerView.trailingAnchor, constant: -14),
            noteLabel.bottomAnchor.constraint(equalTo: noteContainerView.bottomAnchor, constant: -14)
        ])
    }
}
