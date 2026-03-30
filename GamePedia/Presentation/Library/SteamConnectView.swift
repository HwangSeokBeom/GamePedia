import UIKit

final class SteamConnectView: UIView {
    var onConnectButtonTapped: (() -> Void)?

    private let steamIconImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "gamecontroller.fill"))
        imageView.tintColor = .gpPrimary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Steam 계정을 연결하세요"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .gpTextPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Steam 계정을 연결하면 플레이 기록과 보유 게임을 자동으로 가져올 수 있어요."
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let connectButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Steam 계정 연동하기"
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

    private func setupView() {
        backgroundColor = .clear

        addSubview(contentStackView)
        [steamIconImageView, titleLabel, descriptionLabel, connectButton].forEach {
            contentStackView.addArrangedSubview($0)
        }

        connectButton.addTarget(self, action: #selector(didTapConnectButton), for: .touchUpInside)

        steamIconImageView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        steamIconImageView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        descriptionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            contentStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])

        contentStackView.setCustomSpacing(16, after: steamIconImageView)
        contentStackView.setCustomSpacing(12, after: titleLabel)
        contentStackView.setCustomSpacing(24, after: descriptionLabel)
    }

    @objc
    private func didTapConnectButton() {
        onConnectButtonTapped?()
    }
}
