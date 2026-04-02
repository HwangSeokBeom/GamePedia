import UIKit

final class SteamUnavailableView: UIView {
    var onRetryButtonTapped: (() -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "library.steam.unavailable.title")
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .gpTextPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "library.steam.unavailable.message")
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let errorCodeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextTertiary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let retryButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = L10n.Common.Button.retry
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupLayout()
    }

    func configure(errorCode: String?) {
        if let errorCode, !errorCode.isEmpty {
            errorCodeLabel.text = L10n.tr("Localizable", "library.steam.unavailable.errorCode", errorCode)
            errorCodeLabel.isHidden = false
        } else {
            errorCodeLabel.text = nil
            errorCodeLabel.isHidden = true
        }
    }

    private func setupView() {
        backgroundColor = .clear

        addSubview(contentStackView)
        [titleLabel, descriptionLabel, errorCodeLabel, retryButton].forEach {
            contentStackView.addArrangedSubview($0)
        }

        retryButton.addTarget(self, action: #selector(didTapRetryButton), for: .touchUpInside)
        descriptionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true
        errorCodeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            contentStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])

        contentStackView.setCustomSpacing(12, after: titleLabel)
        contentStackView.setCustomSpacing(12, after: descriptionLabel)
        contentStackView.setCustomSpacing(24, after: errorCodeLabel)
    }

    @objc
    private func didTapRetryButton() {
        onRetryButtonTapped?()
    }
}
