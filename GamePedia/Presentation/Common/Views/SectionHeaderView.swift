import UIKit

// MARK: - SectionHeaderView

final class SectionHeaderView: UIView {

    // MARK: Subviews
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .gpTextPrimary
        return label
    }()

    let seeMoreButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "더보기"
        config.baseForegroundColor = .gpPrimary
        config.contentInsets = .zero
        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let leadingStack = UIStackView(arrangedSubviews: [iconImageView, titleLabel])
        leadingStack.axis = .horizontal
        leadingStack.alignment = .center
        leadingStack.spacing = 10
        leadingStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [leadingStack, UIView(), seeMoreButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),

            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    // MARK: Configure
    func configure(
        title: String,
        systemImageName: String? = nil,
        tintColor: UIColor = .gpTextPrimary,
        showSeeMore: Bool = true
    ) {
        titleLabel.text = title
        if let systemImageName {
            let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            iconImageView.image = UIImage(systemName: systemImageName, withConfiguration: configuration)
            iconImageView.tintColor = tintColor
            iconImageView.isHidden = false
        } else {
            iconImageView.image = nil
            iconImageView.isHidden = true
        }
        seeMoreButton.isHidden = !showSeeMore
    }
}
