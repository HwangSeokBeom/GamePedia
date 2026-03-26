import UIKit

final class TodayRecommendationSkeletonCell: UICollectionViewCell {

    static let reuseId = "TodayRecommendationSkeletonCell"

    private let thumbnailPlaceholder = SkeletonPlaceholderView(cornerRadius: 14)
    private let badgePlaceholder = SkeletonPlaceholderView(cornerRadius: 10)
    private let titlePlaceholderTop = SkeletonPlaceholderView(cornerRadius: 8)
    private let titlePlaceholderBottom = SkeletonPlaceholderView(cornerRadius: 8)
    private let subtitlePlaceholder = SkeletonPlaceholderView(cornerRadius: 7)
    private let metaPlaceholder = SkeletonPlaceholderView(cornerRadius: 7)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        contentView.backgroundColor = .gpSurfaceElevated
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        let textStack = UIStackView(arrangedSubviews: [
            badgePlaceholder,
            titlePlaceholderTop,
            titlePlaceholderBottom,
            subtitlePlaceholder,
            metaPlaceholder
        ])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 8
        textStack.translatesAutoresizingMaskIntoConstraints = false

        [textStack, thumbnailPlaceholder].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            thumbnailPlaceholder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            thumbnailPlaceholder.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailPlaceholder.widthAnchor.constraint(equalToConstant: 96),
            thumbnailPlaceholder.heightAnchor.constraint(equalToConstant: 132),

            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: thumbnailPlaceholder.leadingAnchor, constant: -14),

            badgePlaceholder.widthAnchor.constraint(equalToConstant: 92),
            badgePlaceholder.heightAnchor.constraint(equalToConstant: 22),
            titlePlaceholderTop.widthAnchor.constraint(equalToConstant: 144),
            titlePlaceholderTop.heightAnchor.constraint(equalToConstant: 20),
            titlePlaceholderBottom.widthAnchor.constraint(equalToConstant: 128),
            titlePlaceholderBottom.heightAnchor.constraint(equalToConstant: 20),
            subtitlePlaceholder.widthAnchor.constraint(equalToConstant: 116),
            subtitlePlaceholder.heightAnchor.constraint(equalToConstant: 14),
            metaPlaceholder.widthAnchor.constraint(equalToConstant: 108),
            metaPlaceholder.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
}

final class GameHorizontalSkeletonCell: UICollectionViewCell {

    static let reuseId = "GameHorizontalSkeletonCell"

    private let thumbnailPlaceholder = SkeletonPlaceholderView(cornerRadius: 12)
    private let titlePlaceholderTop = SkeletonPlaceholderView(cornerRadius: 8)
    private let titlePlaceholderBottom = SkeletonPlaceholderView(cornerRadius: 8)
    private let ratingPlaceholder = SkeletonPlaceholderView(cornerRadius: 6)
    private let genrePlaceholder = SkeletonPlaceholderView(cornerRadius: 6)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear

        [thumbnailPlaceholder, titlePlaceholderTop, titlePlaceholderBottom, ratingPlaceholder, genrePlaceholder]
            .forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            thumbnailPlaceholder.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailPlaceholder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailPlaceholder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailPlaceholder.heightAnchor.constraint(equalToConstant: 180),

            titlePlaceholderTop.topAnchor.constraint(equalTo: thumbnailPlaceholder.bottomAnchor, constant: 8),
            titlePlaceholderTop.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titlePlaceholderTop.widthAnchor.constraint(equalToConstant: 118),
            titlePlaceholderTop.heightAnchor.constraint(equalToConstant: 16),

            titlePlaceholderBottom.topAnchor.constraint(equalTo: titlePlaceholderTop.bottomAnchor, constant: 6),
            titlePlaceholderBottom.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titlePlaceholderBottom.widthAnchor.constraint(equalToConstant: 86),
            titlePlaceholderBottom.heightAnchor.constraint(equalToConstant: 16),

            ratingPlaceholder.topAnchor.constraint(equalTo: titlePlaceholderBottom.bottomAnchor, constant: 8),
            ratingPlaceholder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            ratingPlaceholder.widthAnchor.constraint(equalToConstant: 72),
            ratingPlaceholder.heightAnchor.constraint(equalToConstant: 12),

            genrePlaceholder.topAnchor.constraint(equalTo: ratingPlaceholder.bottomAnchor, constant: 7),
            genrePlaceholder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            genrePlaceholder.widthAnchor.constraint(equalToConstant: 64),
            genrePlaceholder.heightAnchor.constraint(equalToConstant: 11)
        ])
    }
}

final class GameRowSkeletonCell: UICollectionViewCell {

    static let reuseId = "GameRowSkeletonCell"

    private let thumbnailPlaceholder = SkeletonPlaceholderView(cornerRadius: 10)
    private let titlePlaceholder = SkeletonPlaceholderView(cornerRadius: 8)
    private let subtitlePlaceholder = SkeletonPlaceholderView(cornerRadius: 7)
    private let buttonPlaceholder = SkeletonPlaceholderView(cornerRadius: 16)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        contentView.backgroundColor = .gpSurfaceElevated
        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        [thumbnailPlaceholder, titlePlaceholder, subtitlePlaceholder, buttonPlaceholder]
            .forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            thumbnailPlaceholder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            thumbnailPlaceholder.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailPlaceholder.widthAnchor.constraint(equalToConstant: 56),
            thumbnailPlaceholder.heightAnchor.constraint(equalToConstant: 56),

            buttonPlaceholder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            buttonPlaceholder.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            buttonPlaceholder.widthAnchor.constraint(equalToConstant: 84),
            buttonPlaceholder.heightAnchor.constraint(equalToConstant: 32),

            titlePlaceholder.leadingAnchor.constraint(equalTo: thumbnailPlaceholder.trailingAnchor, constant: 12),
            titlePlaceholder.trailingAnchor.constraint(equalTo: buttonPlaceholder.leadingAnchor, constant: -12),
            titlePlaceholder.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            titlePlaceholder.heightAnchor.constraint(equalToConstant: 16),

            subtitlePlaceholder.leadingAnchor.constraint(equalTo: thumbnailPlaceholder.trailingAnchor, constant: 12),
            subtitlePlaceholder.topAnchor.constraint(equalTo: titlePlaceholder.bottomAnchor, constant: 8),
            subtitlePlaceholder.widthAnchor.constraint(equalToConstant: 128),
            subtitlePlaceholder.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
}
