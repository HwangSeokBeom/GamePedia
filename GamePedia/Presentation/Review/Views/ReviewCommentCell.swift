import UIKit

final class ReviewCommentCell: UITableViewCell {
    static let reuseIdentifier = "ReviewCommentCell"

    struct ViewState: Equatable {
        let id: String
        let authorName: String
        let authorAvatarURL: URL?
        let bodyText: String
        let dateText: String
        let depth: Int
        let isMine: Bool
        let isDeleted: Bool
        let likeCount: Int
        let myReaction: ReviewCommentReaction?
        let showsActions: Bool
        let canReply: Bool
        let isReactionLoading: Bool
    }

    var onReplyTapped: (() -> Void)?
    var onLikeTapped: (() -> Void)?
    var onMoreTapped: (() -> Void)?

    private let highlightBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let avatarInitialLabel: UILabel = {
        let label = UILabel()
        label.textColor = .gpAvatarInitialText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .gpTextPrimary
        return label
    }()

    private let mineBadgeLabel: UILabel = {
        let label = InsetLabel(insets: UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6))
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = .gpPrimary
        label.layer.cornerRadius = 9
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        label.text = L10n.tr("Localizable", "review.comment.badge.mine")
        label.isHidden = true
        return label
    }()

    private let moreButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "ellipsis",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        configuration.baseForegroundColor = .gpTextTertiary
        configuration.contentInsets = .zero
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let firstMetaDot: UILabel = {
        let label = UILabel()
        label.text = "·"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let secondMetaDot: UILabel = {
        let label = UILabel()
        label.text = "·"
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let likeButton = UIButton(type: .system)
    private let replyButton = UIButton(type: .system)
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var leadingConstraint: NSLayoutConstraint?
    private var avatarSizeConstraint: NSLayoutConstraint?
    private var contentTopConstraint: NSLayoutConstraint?
    private var metaBottomConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with viewState: ViewState) {
        let isReply = viewState.depth > 0
        let leadingInset: CGFloat = isReply ? 56 : 20
        let avatarSize: CGFloat = isReply ? 24 : 28
        let topBottomInset: CGFloat = isReply ? 10 : 14

        leadingConstraint?.constant = leadingInset
        avatarSizeConstraint?.constant = avatarSize
        contentTopConstraint?.constant = topBottomInset
        metaBottomConstraint?.constant = topBottomInset

        avatarView.layer.cornerRadius = avatarSize / 2
        highlightBackgroundView.layer.cornerRadius = isReply ? 12 : 14

        avatarView.backgroundColor = ReviewCommentAvatarPalette.color(for: viewState.authorName)
        avatarView.loadImage(url: viewState.authorAvatarURL)
        avatarInitialLabel.text = String(viewState.authorName.first ?? " ")
        avatarInitialLabel.font = .systemFont(ofSize: isReply ? 10 : 11, weight: .semibold)

        authorLabel.text = viewState.authorName
        authorLabel.font = .systemFont(ofSize: isReply ? 13 : 14, weight: .semibold)

        bodyLabel.text = viewState.bodyText
        bodyLabel.font = .systemFont(ofSize: isReply ? 13 : 14)
        bodyLabel.textColor = viewState.isDeleted ? .gpTextTertiary : .gpTextSecondary

        timeLabel.text = viewState.dateText
        mineBadgeLabel.isHidden = !viewState.isMine
        moreButton.isHidden = !viewState.showsActions

        configureLikeButton(with: viewState)
        configureReplyButton(with: viewState)

        let hidesMeta = viewState.isDeleted
        timeLabel.isHidden = hidesMeta
        firstMetaDot.isHidden = hidesMeta
        secondMetaDot.isHidden = hidesMeta
        likeButton.isHidden = hidesMeta
        replyButton.isHidden = hidesMeta
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        avatarInitialLabel.text = nil
        onReplyTapped = nil
        onLikeTapped = nil
        onMoreTapped = nil
    }

    func animateHighlight() {
        UIView.animate(withDuration: 0.18, animations: {
            self.highlightBackgroundView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.18)
        }, completion: { _ in
            UIView.animate(withDuration: 0.4) {
                self.highlightBackgroundView.backgroundColor = .clear
            }
        })
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        avatarView.addSubview(avatarInitialLabel)

        let leftHeaderStack = UIStackView(arrangedSubviews: [avatarView, authorLabel, mineBadgeLabel])
        leftHeaderStack.axis = .horizontal
        leftHeaderStack.alignment = .center
        leftHeaderStack.spacing = 8

        let headerRow = UIStackView(arrangedSubviews: [leftHeaderStack, UIView(), moreButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center

        configureMetaButton(likeButton, selector: #selector(didTapLike))
        configureMetaButton(replyButton, selector: #selector(didTapReply))

        let metaRow = UIStackView(arrangedSubviews: [timeLabel, firstMetaDot, likeButton, secondMetaDot, replyButton, UIView()])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 6

        let contentStack = UIStackView(arrangedSubviews: [headerRow, bodyLabel, metaRow])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(highlightBackgroundView)
        highlightBackgroundView.addSubview(contentStack)
        highlightBackgroundView.addSubview(separatorView)

        leadingConstraint = highlightBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20)
        avatarSizeConstraint = avatarView.widthAnchor.constraint(equalToConstant: 28)
        contentTopConstraint = contentStack.topAnchor.constraint(equalTo: highlightBackgroundView.topAnchor, constant: 14)
        metaBottomConstraint = separatorView.topAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 14)

        leadingConstraint?.isActive = true
        avatarSizeConstraint?.isActive = true
        contentTopConstraint?.isActive = true
        metaBottomConstraint?.isActive = true

        NSLayoutConstraint.activate([
            highlightBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            highlightBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            highlightBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),
            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            contentStack.leadingAnchor.constraint(equalTo: highlightBackgroundView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: highlightBackgroundView.trailingAnchor),

            moreButton.widthAnchor.constraint(equalToConstant: 32),
            moreButton.heightAnchor.constraint(equalToConstant: 32),

            separatorView.leadingAnchor.constraint(equalTo: highlightBackgroundView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: highlightBackgroundView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: highlightBackgroundView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])

        moreButton.addTarget(self, action: #selector(didTapMore), for: .touchUpInside)
    }

    private func configureLikeButton(with viewState: ViewState) {
        let isLiked = viewState.myReaction == .like
        let tintColor: UIColor = isLiked ? .gpCoral : .gpTextTertiary
        var configuration = likeButton.configuration
        configuration?.title = String(viewState.likeCount)
        configuration?.image = UIImage(
            systemName: isLiked ? "heart.fill" : "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        )
        configuration?.baseForegroundColor = tintColor
        configuration?.imagePadding = 4
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        likeButton.configuration = configuration
        likeButton.isEnabled = !viewState.isReactionLoading && !viewState.isDeleted
        likeButton.alpha = viewState.likeCount == 0 && !isLiked ? 0.72 : 1
        likeButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.like", String(viewState.likeCount))
    }

    private func configureReplyButton(with viewState: ViewState) {
        var configuration = replyButton.configuration
        configuration?.title = L10n.tr("Localizable", "review.comment.action.reply")
        configuration?.baseForegroundColor = .gpTextSecondary
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        replyButton.configuration = configuration
        replyButton.isEnabled = viewState.canReply && !viewState.isDeleted
        replyButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.reply")
    }

    private func configureMetaButton(_ button: UIButton, selector: Selector) {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        configuration.imagePadding = 4
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.addTarget(self, action: selector, for: .touchUpInside)
    }

    @objc private func didTapReply() {
        onReplyTapped?()
    }

    @objc private func didTapLike() {
        onLikeTapped?()
    }

    @objc private func didTapMore() {
        onMoreTapped?()
    }
}

private enum ReviewCommentAvatarPalette {
    private static let colors: [UIColor] = [
        UIColor(hex: "#6366F1"),
        UIColor(hex: "#3B5998"),
        UIColor(hex: "#2E8B57"),
        UIColor(hex: "#8B5CF6"),
        UIColor(hex: "#E85A4F"),
        UIColor(hex: "#FFB547")
    ]

    static func color(for seed: String) -> UIColor {
        colors[abs(seed.hashValue) % colors.count]
    }
}

private final class InsetLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
