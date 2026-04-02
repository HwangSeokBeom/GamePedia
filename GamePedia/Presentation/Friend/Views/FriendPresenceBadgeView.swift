import UIKit

struct UserPresenceDisplayModel: Hashable {
    let text: String
    let dotColor: UIColor
    let textColor: UIColor
}

enum UserPresenceDisplayFormatter {
    static func makeDisplayModel(from presence: UserPresence?) -> UserPresenceDisplayModel? {
        guard let presence else { return nil }

        switch presence.state {
        case .online:
            return UserPresenceDisplayModel(
                text: "온라인",
                dotColor: .systemGreen,
                textColor: .gpTextSecondary
            )
        case .playing:
            if let gameTitle = sanitized(presence.gameTitle) {
                return UserPresenceDisplayModel(
                    text: "\(gameTitle) 플레이 중",
                    dotColor: .gpPrimary,
                    textColor: .gpTextSecondary
                )
            }
            return UserPresenceDisplayModel(
                text: "플레이 중",
                dotColor: .gpPrimary,
                textColor: .gpTextSecondary
            )
        case .recentlyActive:
            return UserPresenceDisplayModel(
                text: "최근 활동",
                dotColor: .gpStar,
                textColor: .gpTextSecondary
            )
        case .lastPlayed:
            return UserPresenceDisplayModel(
                text: "최근 플레이",
                dotColor: .gpTextTertiary,
                textColor: .gpTextSecondary
            )
        case .unknown:
            return nil
        }
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class FriendPresenceBadgeView: UIView {
    private let dotView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with displayModel: UserPresenceDisplayModel?) {
        guard let displayModel else {
            isHidden = true
            return
        }

        isHidden = false
        label.text = displayModel.text
        label.textColor = displayModel.textColor
        dotView.backgroundColor = displayModel.dotColor
    }

    private func setup() {
        backgroundColor = UIColor.gpSurfaceElevated.withAlphaComponent(0.72)
        layer.cornerRadius = 11
        layer.cornerCurve = .continuous
        isHidden = true
        translatesAutoresizingMaskIntoConstraints = false

        [dotView, label].forEach { addSubview($0) }

        NSLayoutConstraint.activate([
            dotView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),

            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}
