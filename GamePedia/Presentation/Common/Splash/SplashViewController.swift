import UIKit

final class SplashViewController: UIViewController {

    private enum Metrics {
        static let glowSide: CGFloat = 148
        static let logoContainerSide: CGFloat = 88
        static let logoWidth: CGFloat = 30
        static let logoHeight: CGFloat = 22
        static let titleTopSpacing: CGFloat = 32
        static let subtitleTopSpacing: CGFloat = 6
    }

    private let centerGroupView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let glowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.14)
        view.layer.cornerRadius = Metrics.glowSide / 2
        view.layer.shadowColor = UIColor.gpPrimary.cgColor
        view.layer.shadowOpacity = 0.45
        view.layer.shadowRadius = 34
        view.layer.shadowOffset = .zero
        return view
    }()

    private let logoContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 24
        view.layer.borderWidth = 1
        view.backgroundColor = .gpSurface
        view.layer.shadowOpacity = 0.18
        view.layer.shadowRadius = 28
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
        return view
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "logoIcon")?.withRenderingMode(.alwaysOriginal))
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "GamePedia"
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        let descriptor = baseDescriptor.withDesign(.serif) ?? baseDescriptor
        label.font = UIFont(descriptor: descriptor, size: 36)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "게임을 발견하고 기록하세요"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyDynamicLayerColors()
    }

    private func setupView() {
        view.backgroundColor = .gpBackground
        view.addSubview(centerGroupView)
        centerGroupView.addSubview(glowView)
        centerGroupView.addSubview(logoContainerView)
        centerGroupView.addSubview(titleLabel)
        centerGroupView.addSubview(subtitleLabel)
        logoContainerView.addSubview(logoImageView)
        applyDynamicLayerColors()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            centerGroupView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerGroupView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerGroupView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            centerGroupView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            glowView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
            glowView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            glowView.widthAnchor.constraint(equalToConstant: Metrics.glowSide),
            glowView.heightAnchor.constraint(equalToConstant: Metrics.glowSide),

            logoContainerView.topAnchor.constraint(equalTo: centerGroupView.topAnchor),
            logoContainerView.centerXAnchor.constraint(equalTo: centerGroupView.centerXAnchor),
            logoContainerView.widthAnchor.constraint(equalToConstant: Metrics.logoContainerSide),
            logoContainerView.heightAnchor.constraint(equalToConstant: Metrics.logoContainerSide),

            titleLabel.topAnchor.constraint(equalTo: logoContainerView.bottomAnchor, constant: Metrics.titleTopSpacing),
            titleLabel.centerXAnchor.constraint(equalTo: centerGroupView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Metrics.subtitleTopSpacing),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerGroupView.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: centerGroupView.bottomAnchor),

            logoImageView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: Metrics.logoWidth),
            logoImageView.heightAnchor.constraint(equalToConstant: Metrics.logoHeight)
        ])
    }

    private func applyDynamicLayerColors() {
        glowView.layer.shadowColor = UIColor.gpPrimary.resolvedCGColor(with: traitCollection)
        logoContainerView.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
        logoContainerView.layer.shadowColor = UIColor.gpPrimary.resolvedCGColor(with: traitCollection)
    }
}
