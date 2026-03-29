import UIKit

final class LibraryGameRowCell: UICollectionViewCell {

    static let reuseId = "LibraryGameRowCell"
    var onTrailingActionTapped: (() -> Void)?

    private let thumbnailView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .gpTextTertiary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let ratingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpStar
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let trailingButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = UIColor.gpPrimary.withAlphaComponent(0.12)
        configuration.baseForegroundColor = .gpPrimaryLight
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        configuration.image = UIImage(
            systemName: "heart.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        configuration.title = "찜됨"
        configuration.imagePadding = 4
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var trailingButtonWidthConstraint: NSLayoutConstraint?
    private var textStackTrailingToButtonConstraint: NSLayoutConstraint?
    private var textStackTrailingToContentConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.cancelLoad()
        thumbnailView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        metadataLabel.text = nil
        ratingLabel.text = nil
        applyTrailingActionVisibility(false)
        onTrailingActionTapped = nil
    }

    func configure(with viewState: LibraryGameRowViewState) {
        thumbnailView.loadImage(url: viewState.coverImageURL)
        titleLabel.text = viewState.title
        subtitleLabel.text = viewState.subtitleText
        metadataLabel.text = viewState.metadataText

        if let ratingText = viewState.ratingText {
            ratingLabel.text = "★ \(ratingText)"
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }

        applyTrailingActionVisibility(viewState.trailingAction != nil)
    }

    private func setup() {
        contentView.backgroundColor = .gpCardBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, metadataLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        [thumbnailView, textStack, ratingLabel, trailingButton].forEach {
            contentView.addSubview($0)
        }

        trailingButton.addTarget(self, action: #selector(didTapTrailingButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumbnailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            thumbnailView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailView.heightAnchor.constraint(equalToConstant: 60),

            trailingButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            trailingButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            ratingLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            ratingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        let trailingButtonWidthConstraint = trailingButton.widthAnchor.constraint(equalToConstant: 68)
        let textStackTrailingToButtonConstraint = textStack.trailingAnchor.constraint(
            equalTo: trailingButton.leadingAnchor,
            constant: -12
        )
        let textStackTrailingToContentConstraint = textStack.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -12
        )

        self.trailingButtonWidthConstraint = trailingButtonWidthConstraint
        self.textStackTrailingToButtonConstraint = textStackTrailingToButtonConstraint
        self.textStackTrailingToContentConstraint = textStackTrailingToContentConstraint

        NSLayoutConstraint.activate([
            trailingButtonWidthConstraint,
            textStackTrailingToButtonConstraint
        ])

        applyTrailingActionVisibility(false)
    }

    @objc
    private func didTapTrailingButton() {
        onTrailingActionTapped?()
    }

    private func applyTrailingActionVisibility(_ isVisible: Bool) {
        trailingButton.isHidden = !isVisible
        trailingButtonWidthConstraint?.constant = isVisible ? 68 : 0
        textStackTrailingToButtonConstraint?.isActive = isVisible
        textStackTrailingToContentConstraint?.isActive = !isVisible
    }
}
