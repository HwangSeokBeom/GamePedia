import UIKit

final class SteamPrivacyInstructionsViewController: UIViewController {
    var onOpenSteamSettings: (() -> Void)?

    private let contentView = SteamPrivacyInstructionsContentView()

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpSurface
        title = L10n.tr("Localizable", "library.steam.privacy.instructions.title")

        contentView.configure(
            summary: SteamPrivacyGuideContent.summary,
            steps: SteamPrivacyGuideContent.steps
        )
        contentView.onOpenSteamSettingsTapped = { [weak self] in
            self?.onOpenSteamSettings?()
        }
    }
}

private final class SteamPrivacyInstructionsContentView: UIView {
    var onOpenSteamSettingsTapped: (() -> Void)?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let openSteamSettingsButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .large
        configuration.title = L10n.tr("Localizable", "library.steam.privacy.instructions.openSettings")
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
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

    func configure(summary: String, steps: [SteamPrivacyGuideStep]) {
        summaryLabel.text = summary

        contentStack.arrangedSubviews
            .filter { $0 is SteamPrivacyInstructionCardView }
            .forEach { subview in
                contentStack.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }

        steps
            .enumerated()
            .map { SteamPrivacyInstructionCardView(index: $0.offset + 1, step: $0.element) }
            .forEach { contentStack.insertArrangedSubview($0, at: max(contentStack.arrangedSubviews.count - 1, 1)) }
    }

    private func setup() {
        backgroundColor = .gpSurface

        addSubview(scrollView)
        scrollView.addSubview(contentStack)

        [summaryLabel, openSteamSettingsButton].forEach {
            contentStack.addArrangedSubview($0)
        }

        openSteamSettingsButton.addTarget(self, action: #selector(didTapOpenSteamSettings), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    @objc
    private func didTapOpenSteamSettings() {
        onOpenSteamSettingsTapped?()
    }
}

private final class SteamPrivacyInstructionCardView: UIView {
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .gpPrimaryLight
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let numberBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.16)
        view.layer.cornerRadius = 22
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .gpPrimaryLight
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    init(index: Int, step: SteamPrivacyGuideStep) {
        super.init(frame: .zero)
        setup()

        numberLabel.text = "\(index)"
        iconView.image = UIImage(
            systemName: step.iconSystemName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        )
        titleLabel.text = step.title
        detailLabel.text = step.detail
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 20
        layer.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        let headerStack = UIStackView(arrangedSubviews: [numberBackgroundView, titleLabel])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 12
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let bodyStack = UIStackView(arrangedSubviews: [headerStack, detailLabel])
        bodyStack.axis = .vertical
        bodyStack.spacing = 10
        bodyStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(bodyStack)
        numberBackgroundView.addSubview(numberLabel)
        numberBackgroundView.addSubview(iconView)

        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            bodyStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            bodyStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            bodyStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),

            numberBackgroundView.widthAnchor.constraint(equalToConstant: 44),
            numberBackgroundView.heightAnchor.constraint(equalToConstant: 44),

            numberLabel.centerXAnchor.constraint(equalTo: numberBackgroundView.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: numberBackgroundView.centerYAnchor),

            iconView.trailingAnchor.constraint(equalTo: numberBackgroundView.trailingAnchor, constant: -6),
            iconView.bottomAnchor.constraint(equalTo: numberBackgroundView.bottomAnchor, constant: -6),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
}
