import UIKit

final class SteamPrivacyGuidanceViewController: UIViewController {
    var onShowInstructions: (() -> Void)?
    var onRetry: (() -> Void)?

    private let contentView = SteamPrivacyGuidanceContentView()

    override func loadView() {
        view = contentView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpSurface
        title = L10n.tr("Localizable", "library.steam.privacy.guidance.title")

        contentView.configure(
            title: SteamPrivacyGuideContent.title,
            summary: SteamPrivacyGuideContent.summary,
            steps: SteamPrivacyGuideContent.steps
        )
        contentView.onShowInstructionsTapped = { [weak self] in
            self?.onShowInstructions?()
        }
        contentView.onRetryTapped = { [weak self] in
            self?.onRetry?()
        }
        contentView.onLaterTapped = { [weak self] in
            self?.dismiss(animated: true)
        }
    }
}

private final class SteamPrivacyGuidanceContentView: UIView {
    var onShowInstructionsTapped: (() -> Void)?
    var onRetryTapped: (() -> Void)?
    var onLaterTapped: (() -> Void)?

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let stepsStack: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        return stackView
    }()

    private let showInstructionsButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .large
        configuration.title = L10n.tr("Localizable", "library.steam.privacy.guidance.showInstructions")
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let retryButton: UIButton = {
        var configuration = UIButton.Configuration.tinted()
        configuration.baseBackgroundColor = .gpPrimary.withAlphaComponent(0.12)
        configuration.baseForegroundColor = .gpPrimaryLight
        configuration.cornerStyle = .large
        configuration.title = L10n.tr("Localizable", "library.steam.privacy.guidance.retry")
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let laterButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .gpTextSecondary
        configuration.title = L10n.tr("Localizable", "common.button.later")
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
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

    func configure(title: String, summary: String, steps: [SteamPrivacyGuideStep]) {
        titleLabel.text = title
        summaryLabel.text = summary

        stepsStack.arrangedSubviews.forEach { subview in
            stepsStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        steps
            .enumerated()
            .map { SteamPrivacyStepRowView(index: $0.offset + 1, step: $0.element) }
            .forEach { stepsStack.addArrangedSubview($0) }
    }

    private func setup() {
        backgroundColor = .gpSurface

        addSubview(scrollView)
        scrollView.addSubview(contentStack)

        let buttonStack = UIStackView(arrangedSubviews: [showInstructionsButton, retryButton, laterButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 10

        [titleLabel, summaryLabel, stepsStack, buttonStack].forEach {
            contentStack.addArrangedSubview($0)
        }

        showInstructionsButton.addTarget(self, action: #selector(didTapShowInstructions), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)
        laterButton.addTarget(self, action: #selector(didTapLater), for: .touchUpInside)

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
    private func didTapShowInstructions() {
        onShowInstructionsTapped?()
    }

    @objc
    private func didTapRetry() {
        onRetryTapped?()
    }

    @objc
    private func didTapLater() {
        onLaterTapped?()
    }
}

private final class SteamPrivacyStepRowView: UIView {
    private let iconContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
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
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 0
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    init(index: Int, step: SteamPrivacyGuideStep) {
        super.init(frame: .zero)
        setup()
        iconView.image = UIImage(
            systemName: step.iconSystemName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        )
        titleLabel.text = "\(index). \(step.title)"
        detailLabel.text = step.detail
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 18
        layer.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconContainerView)
        iconContainerView.addSubview(iconView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainerView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconContainerView.widthAnchor.constraint(equalToConstant: 44),
            iconContainerView.heightAnchor.constraint(equalToConstant: 44),

            iconView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            textStack.leadingAnchor.constraint(equalTo: iconContainerView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }
}
