import UIKit

final class LibraryInfoCell: UICollectionViewCell {

    static let reuseId = "LibraryInfoCell"
    var onButtonTapped: (() -> Void)?

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let actionButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

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
        titleLabel.text = nil
        messageLabel.text = nil
        detailLabel.text = nil
        detailLabel.isHidden = true
        actionButton.isHidden = true
        onButtonTapped = nil
    }

    func configure(with viewState: LibraryMessageViewState) {
        titleLabel.text = viewState.title
        titleLabel.isHidden = viewState.title == nil
        messageLabel.text = viewState.message
        detailLabel.text = viewState.detailText
        detailLabel.isHidden = viewState.detailText == nil

        var buttonConfiguration = actionButton.configuration
        buttonConfiguration?.title = viewState.buttonTitle
        actionButton.configuration = buttonConfiguration
        actionButton.isHidden = viewState.buttonTitle == nil

        switch viewState.style {
        case .banner:
            contentView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.08)
            iconView.image = UIImage(systemName: "link.circle.fill")
            iconView.tintColor = .gpPrimaryLight
        case .empty:
            contentView.backgroundColor = .gpCardBackground
            iconView.image = UIImage(systemName: "tray")
            iconView.tintColor = .gpTextTertiary
        case .error:
            contentView.backgroundColor = UIColor.gpOrange.withAlphaComponent(0.10)
            iconView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            iconView.tintColor = .gpOrange
        }
    }

    private func setup() {
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        [iconView, textStack, actionButton].forEach { contentView.addSubview($0) }
        actionButton.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            actionButton.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 12),
            actionButton.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            actionButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    @objc
    private func didTapButton() {
        onButtonTapped?()
    }
}
