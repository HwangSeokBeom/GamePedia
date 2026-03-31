import UIKit

final class HomeNavigationIconButton: UIControl {
    private let imageView = UIImageView()
    private let badgeView = UIView()

    init(systemImageName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.backgroundColor = .gpCoral
        badgeView.layer.cornerRadius = 4
        badgeView.isHidden = true

        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        imageView.image = UIImage(systemName: systemImageName, withConfiguration: configuration)
        imageView.tintColor = .gpTextSecondary
        imageView.contentMode = .scaleAspectFit

        addSubview(imageView)
        addSubview(badgeView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            heightAnchor.constraint(equalToConstant: 28),

            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),

            badgeView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            badgeView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            badgeView.widthAnchor.constraint(equalToConstant: 8),
            badgeView.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTintColor(_ color: UIColor) {
        imageView.tintColor = color
    }

    func setBadgeVisible(_ isVisible: Bool) {
        badgeView.isHidden = !isVisible
    }
}
