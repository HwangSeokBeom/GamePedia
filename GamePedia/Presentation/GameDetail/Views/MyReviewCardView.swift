import UIKit

final class MyReviewCardView: UIView {
    var onEditTapped: (() -> Void)?

    private let starView = StarRatingView()
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 3
        return label
    }()

    private let editButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.tr("Localizable", "common.button.edit")
        configuration.baseBackgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        configuration.baseForegroundColor = .gpPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 12, weight: .semibold)
            return updated
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

    func configure(with review: Review) {
        starView.configure(rating: review.rating)
        dateLabel.text = review.createdAt.toAbsoluteDateString()
        bodyLabel.text = review.body
    }

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.gpSeparator.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let metaRow = UIStackView(arrangedSubviews: [starView, dateLabel])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 8

        let topRow = UIStackView(arrangedSubviews: [metaRow, UIView(), editButton])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        let stackView = UIStackView(arrangedSubviews: [topRow, bodyLabel])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        editButton.addTarget(self, action: #selector(didTapEdit), for: .touchUpInside)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            editButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func didTapEdit() {
        onEditTapped?()
    }
}

final class MyReviewEmptyStateView: UIView {
    let actionButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.tr("Localizable", "detail.review.emptyAction")
        configuration.image = UIImage(
            systemName: "plus.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        configuration.imagePadding = 6
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18)
        configuration.cornerStyle = .capsule
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: 13, weight: .semibold)
            return updated
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(
            systemName: "square.and.pencil",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        )
        imageView.tintColor = .gpTextTertiary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = L10n.tr("Localizable", "detail.review.emptyTitle")
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextTertiary
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = L10n.tr("Localizable", "detail.review.emptyMessage")
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

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.gpSeparator.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel, actionButton])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            actionButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
}
