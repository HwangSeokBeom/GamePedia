import UIKit

final class SteamReviewLinkageBannerView: UIView {

    var onWriteReviewTapped: (() -> Void)?

    private let badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpOnPrimary
        label.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.92)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let helperLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let ctaButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "GamePedia 리뷰 작성"
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        configuration.image = UIImage(systemName: "pencil", withConfiguration: symbolConfiguration)
        configuration.imagePadding = 6
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

    private func setup() {
        backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.08)
        layer.cornerRadius = 16
        layer.masksToBounds = true

        let badgePadding: CGFloat = 8
        let badgeText = " Steam 리뷰 작성됨 "
        badgeLabel.text = badgeText

        helperLabel.text = "Steam에서 리뷰한 게임이에요.\nGamePedia에도 감상을 남겨보세요."

        ctaButton.addTarget(self, action: #selector(didTapCTA), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [badgeLabel, helperLabel, ctaButton])
        textStack.axis = .vertical
        textStack.spacing = 10
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            badgeLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),

            ctaButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    @objc
    private func didTapCTA() {
        onWriteReviewTapped?()
    }
}
