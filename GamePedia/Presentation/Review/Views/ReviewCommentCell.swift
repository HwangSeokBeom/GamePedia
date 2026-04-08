import UIKit

final class ReviewCommentCell: UITableViewCell {
    static let reuseIdentifier = "ReviewCommentCell"

    private struct MetaStyle {
        let labelFontSize: CGFloat
        let iconPointSize: CGFloat
        let moreIconPointSize: CGFloat
        let horizontalInset: CGFloat
        let imagePadding: CGFloat

        static let standard = MetaStyle(
            labelFontSize: 12,
            iconPointSize: 12,
            moreIconPointSize: 13,
            horizontalInset: 8,
            imagePadding: 4
        )

        static let compact = MetaStyle(
            labelFontSize: 11,
            iconPointSize: 11,
            moreIconPointSize: 12,
            horizontalInset: 6,
            imagePadding: 3
        )
    }

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
        let isReactionLoading: Bool
        let canReply: Bool
        let showsMoreAction: Bool
    }

    var onLikeTapped: (() -> Void)?
    var onReplyTapped: (() -> Void)?
    var onMoreTapped: (() -> Void)?
    private var currentCommentId: String?

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

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
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

    private let likeButton = UIButton(type: .system)
    private let replyButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
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
        currentCommentId = viewState.id
        ReviewDiscussionTrace.log(
            "[ReviewCommentCell] configure cellClass=\(String(describing: type(of: self))) commentId=\(viewState.id) depth=\(viewState.depth) likeCount=\(viewState.likeCount)"
        )
        let isReply = viewState.depth > 0
        let leadingInset: CGFloat = isReply ? 56 : 20
        let avatarSize: CGFloat = isReply ? 24 : 28
        let topBottomInset: CGFloat = isReply ? 10 : 14
        let metaStyle = metaStyle(for: viewState.depth)

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
        timeLabel.font = .systemFont(ofSize: metaStyle.labelFontSize, weight: .medium)
        firstMetaDot.font = .systemFont(ofSize: metaStyle.labelFontSize, weight: .medium)
        mineBadgeLabel.isHidden = !viewState.isMine
        configureLikeButton(with: viewState, metaStyle: metaStyle)
        configureReplyButton(with: viewState, metaStyle: metaStyle)
        configureMoreButton(with: viewState, metaStyle: metaStyle)

        let hidesMeta = viewState.isDeleted
        timeLabel.isHidden = hidesMeta
        firstMetaDot.isHidden = hidesMeta
        likeButton.isHidden = hidesMeta
        replyButton.isHidden = hidesMeta || !viewState.canReply
        moreButton.isHidden = hidesMeta || !viewState.showsMoreAction
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        avatarInitialLabel.text = nil
        onLikeTapped = nil
        onReplyTapped = nil
        onMoreTapped = nil
        currentCommentId = nil
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

        let headerRow = UIStackView(arrangedSubviews: [leftHeaderStack, UIView()])
        headerRow.axis = .horizontal
        headerRow.alignment = .center

        configureMetaButton(likeButton, selector: #selector(didTapLike))
        configureMetaButton(replyButton, selector: #selector(didTapReply))
        configureMetaButton(moreButton, selector: #selector(didTapMore))

        let metaRow = UIStackView(arrangedSubviews: [timeLabel, firstMetaDot, likeButton, replyButton, moreButton, UIView()])
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
            separatorView.leadingAnchor.constraint(equalTo: highlightBackgroundView.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: highlightBackgroundView.trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: highlightBackgroundView.bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])

        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        authorLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func configureLikeButton(with viewState: ViewState, metaStyle: MetaStyle) {
        let isLiked = viewState.myReaction == .like
        let tintColor: UIColor = isLiked ? .gpCoral : .gpTextTertiary
        var configuration = likeButton.configuration
        configuration?.title = String(viewState.likeCount)
        configuration?.image = UIImage(
            systemName: isLiked ? "heart.fill" : "heart",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: metaStyle.iconPointSize, weight: .medium)
        )
        configuration?.baseForegroundColor = tintColor
        configuration?.imagePadding = metaStyle.imagePadding
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: metaStyle.horizontalInset, bottom: 8, trailing: metaStyle.horizontalInset)
        configuration?.titleTextAttributesTransformer = makeMetaTitleAttributesTransformer(
            fontSize: metaStyle.labelFontSize,
            weight: .medium
        )
        likeButton.configuration = configuration
        likeButton.isEnabled = !viewState.isReactionLoading && !viewState.isDeleted
        likeButton.alpha = viewState.likeCount == 0 && !isLiked ? 0.72 : 1
        likeButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.like", String(viewState.likeCount))
        likeButton.accessibilityIdentifier = "reviewComment.likeButton"
    }

    private func configureReplyButton(with viewState: ViewState, metaStyle: MetaStyle) {
        var configuration = replyButton.configuration
        configuration?.title = L10n.tr("Localizable", "review.comment.action.reply")
        configuration?.image = UIImage(
            systemName: "arrowshape.turn.up.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: metaStyle.iconPointSize, weight: .medium)
        )
        configuration?.baseForegroundColor = .gpPrimary
        configuration?.imagePadding = metaStyle.imagePadding
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: metaStyle.horizontalInset, bottom: 8, trailing: metaStyle.horizontalInset)
        configuration?.titleTextAttributesTransformer = makeMetaTitleAttributesTransformer(
            fontSize: metaStyle.labelFontSize,
            weight: .medium
        )
        replyButton.configuration = configuration
        replyButton.isEnabled = viewState.canReply
        replyButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.reply")
        replyButton.accessibilityIdentifier = "reviewComment.replyButton"
    }

    private func configureMoreButton(with viewState: ViewState, metaStyle: MetaStyle) {
        var configuration = moreButton.configuration
        configuration?.title = nil
        configuration?.image = UIImage(
            systemName: "ellipsis",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: metaStyle.moreIconPointSize, weight: .semibold)
        )
        configuration?.baseForegroundColor = .gpTextTertiary
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: metaStyle.horizontalInset, bottom: 8, trailing: metaStyle.horizontalInset)
        moreButton.configuration = configuration
        moreButton.isEnabled = viewState.showsMoreAction
        moreButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.more")
        moreButton.accessibilityIdentifier = "reviewComment.moreButton"
    }

    private func configureMetaButton(_ button: UIButton, selector: Selector) {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        configuration.imagePadding = 4
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.addTarget(self, action: selector, for: .touchUpInside)
    }

    private func metaStyle(for depth: Int) -> MetaStyle {
        depth > 0 ? .compact : .standard
    }

    private func makeMetaTitleAttributesTransformer(
        fontSize: CGFloat,
        weight: UIFont.Weight
    ) -> UIConfigurationTextAttributesTransformer {
        UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = .systemFont(ofSize: fontSize, weight: weight)
            return updated
        }
    }

    @objc private func didTapLike() {
        ReviewDiscussionTrace.log("[ReviewCommentCell] likeTapped commentId=\(currentCommentId ?? "nil")")
        onLikeTapped?()
    }

    @objc private func didTapReply() {
        ReviewDiscussionTrace.log("[ReviewCommentCell] replyTapped commentId=\(currentCommentId ?? "nil")")
        onReplyTapped?()
    }

    @objc private func didTapMore() {
        ReviewDiscussionTrace.log("[ReviewCommentCell] moreTapped commentId=\(currentCommentId ?? "nil")")
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
