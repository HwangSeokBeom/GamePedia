import UIKit

final class HomeNavigationTitleView: UIView {

    private enum Metrics {
        static let iconWidth: CGFloat = 22
        static let iconHeight: CGFloat = 16
    }

    static let preferredSize = CGSize(
        width: Metrics.iconWidth,
        height: Metrics.iconHeight
    )

    private static let fallbackImage = UIImage(systemName: "gamecontroller.fill")?
        .withTintColor(.gpPrimary, renderingMode: .alwaysOriginal)

    private let logoImage = UIImage(named: "logoIcon")?.withRenderingMode(.alwaysOriginal)
        ?? HomeNavigationTitleView.fallbackImage

    private lazy var logoImageView: UIImageView = {
        let imageView = UIImageView(image: logoImage)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = nil
        imageView.clipsToBounds = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var intrinsicContentSize: CGSize {
        Self.preferredSize
    }

    private func setup() {
        isUserInteractionEnabled = false
        addSubview(logoImageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Metrics.iconWidth),
            heightAnchor.constraint(equalToConstant: Metrics.iconHeight),
            logoImageView.topAnchor.constraint(equalTo: topAnchor),
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            logoImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            logoImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
