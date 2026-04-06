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
        let isSelfReply: Bool
        let isReviewAuthor: Bool
        let isDeleted: Bool
        let likeCountText: String?
        let dislikeCountText: String?
        let myReaction: ReviewCommentReaction?
        let replyButtonTitle: String
        let showsActions: Bool
        let isReactionLoading: Bool
    }

    var onReplyTapped: (() -> Void)?
    var onLikeTapped: (() -> Void)?
    var onDislikeTapped: (() -> Void)?
    var onMoreTapped: (() -> Void)?

    private let cardView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14
        imageView.backgroundColor = .gpSurface
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let avatarInitialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .gpAvatarInitialText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let badgeStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.alignment = .center
        return stackView
    }()

    private let likeButton = UIButton(type: .system)
    private let dislikeButton = UIButton(type: .system)
    private let replyButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let actionsStackView = UIStackView()
    private var leadingConstraint: NSLayoutConstraint?
    private var currentViewStateId: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with viewState: ViewState) {
        currentViewStateId = viewState.id
        let indent: CGFloat = viewState.depth == 0 ? 20 : 56
        leadingConstraint?.constant = indent

        avatarView.loadImage(url: viewState.authorAvatarURL)
        avatarInitialLabel.text = String(viewState.authorName.first ?? " ")
        authorLabel.text = viewState.authorName
        dateLabel.text = viewState.dateText
        bodyLabel.text = viewState.bodyText
        bodyLabel.textColor = viewState.isDeleted ? .gpTextTertiary : .gpTextSecondary

        configureBadges(for: viewState)
        configureActions(for: viewState)
        configureCardAppearance(for: viewState)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.cancelLoad()
        avatarView.image = nil
        avatarInitialLabel.text = nil
        onReplyTapped = nil
        onLikeTapped = nil
        onDislikeTapped = nil
        onMoreTapped = nil
    }

    func animateHighlight() {
        let originalColor = cardView.backgroundColor
        UIView.animate(withDuration: 0.18, animations: {
            self.cardView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.22)
        }, completion: { _ in
            UIView.animate(withDuration: 0.4) {
                self.cardView.backgroundColor = originalColor
            }
        })
    }

    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        avatarView.addSubview(avatarInitialLabel)

        let authorRow = UIStackView(arrangedSubviews: [authorLabel, badgeStackView, UIView(), dateLabel])
        authorRow.axis = .horizontal
        authorRow.alignment = .center
        authorRow.spacing = 6

        configureActionButton(likeButton, symbolName: "hand.thumbsup", selector: #selector(didTapLike))
        configureActionButton(dislikeButton, symbolName: "hand.thumbsdown", selector: #selector(didTapDislike))
        configureActionButton(replyButton, symbolName: "arrowshape.turn.up.left", selector: #selector(didTapReply))
        configureActionButton(moreButton, symbolName: "ellipsis", selector: #selector(didTapMore))

        actionsStackView.axis = .horizontal
        actionsStackView.spacing = 6
        actionsStackView.alignment = .center
        [likeButton, dislikeButton, replyButton, moreButton].forEach(actionsStackView.addArrangedSubview)

        let contentStack = UIStackView(arrangedSubviews: [authorRow, bodyLabel, actionsStackView])
        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let horizontalStack = UIStackView(arrangedSubviews: [avatarView, contentStack])
        horizontalStack.axis = .horizontal
        horizontalStack.alignment = .top
        horizontalStack.spacing = 10
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cardView)
        cardView.addSubview(horizontalStack)

        leadingConstraint = cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20)
        leadingConstraint?.isActive = true

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 28),
            avatarView.heightAnchor.constraint(equalToConstant: 28),
            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            horizontalStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            horizontalStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            horizontalStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            horizontalStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
        ])
    }

    private func configureCardAppearance(for viewState: ViewState) {
        if viewState.isDeleted {
            cardView.backgroundColor = .gpSurfaceElevated
            cardView.layer.borderWidth = 0
            return
        }

        if viewState.isSelfReply {
            cardView.backgroundColor = UIColor.gpTeal.withAlphaComponent(0.12)
            cardView.layer.borderWidth = 1
            cardView.layer.borderColor = UIColor.gpTeal.withAlphaComponent(0.24).cgColor
            return
        }

        if viewState.isMine {
            cardView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.10)
            cardView.layer.borderWidth = 1
            cardView.layer.borderColor = UIColor.gpPrimary.withAlphaComponent(0.2).cgColor
            return
        }

        if viewState.isReviewAuthor {
            cardView.backgroundColor = UIColor.gpCoral.withAlphaComponent(0.08)
            cardView.layer.borderWidth = 1
            cardView.layer.borderColor = UIColor.gpCoral.withAlphaComponent(0.18).cgColor
            return
        }

        cardView.backgroundColor = .gpCardBackground
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.18).cgColor
    }

    private func configureBadges(for viewState: ViewState) {
        badgeStackView.arrangedSubviews.forEach {
            badgeStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if viewState.isSelfReply {
            badgeStackView.addArrangedSubview(makeBadge(text: L10n.tr("Localizable", "review.comment.badge.selfReply"), tintColor: .gpTeal))
        } else if viewState.isMine {
            let key = viewState.depth == 0 ? "review.comment.badge.mine" : "review.comment.badge.myReply"
            badgeStackView.addArrangedSubview(makeBadge(text: L10n.tr("Localizable", key), tintColor: .gpPrimary))
        }

        if viewState.isReviewAuthor {
            badgeStackView.addArrangedSubview(makeBadge(text: L10n.tr("Localizable", "review.comment.badge.reviewAuthor"), tintColor: .gpCoral))
        }

        if viewState.isDeleted {
            badgeStackView.addArrangedSubview(makeBadge(text: L10n.tr("Localizable", "review.comment.badge.deleted"), tintColor: .gpTextSecondary))
        }
    }

    private func configureActions(for viewState: ViewState) {
        likeButton.isEnabled = !viewState.isReactionLoading && !viewState.isDeleted
        dislikeButton.isEnabled = !viewState.isReactionLoading && !viewState.isDeleted
        replyButton.isEnabled = !viewState.isDeleted

        var likeConfiguration = likeButton.configuration
        likeConfiguration?.title = viewState.likeCountText
        likeButton.configuration = likeConfiguration

        var dislikeConfiguration = dislikeButton.configuration
        dislikeConfiguration?.title = viewState.dislikeCountText
        dislikeButton.configuration = dislikeConfiguration

        var replyConfiguration = replyButton.configuration
        replyConfiguration?.title = viewState.replyButtonTitle
        replyButton.configuration = replyConfiguration
        moreButton.isHidden = !viewState.showsActions

        let likeTint: UIColor = viewState.myReaction == .like ? .gpTeal : .gpTextSecondary
        let dislikeTint: UIColor = viewState.myReaction == .dislike ? .gpCoral : .gpTextSecondary
        updateActionButtonAppearance(button: likeButton, tintColor: likeTint, selected: viewState.myReaction == .like)
        updateActionButtonAppearance(button: dislikeButton, tintColor: dislikeTint, selected: viewState.myReaction == .dislike)
        updateActionButtonAppearance(button: replyButton, tintColor: .gpTextSecondary, selected: false)
        updateActionButtonAppearance(button: moreButton, tintColor: .gpTextSecondary, selected: false)

        let likeCountText = viewState.likeCountText ?? "0"
        let dislikeCountText = viewState.dislikeCountText ?? "0"
        likeButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.like", likeCountText)
        dislikeButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.dislike", dislikeCountText)
        replyButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.reply")
        moreButton.accessibilityLabel = L10n.tr("Localizable", "review.comment.accessibility.more")
    }

    private func configureActionButton(_ button: UIButton, symbolName: String, selector: Selector) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
        button.configuration = configuration
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.addTarget(self, action: selector, for: .touchUpInside)
    }

    private func updateActionButtonAppearance(button: UIButton, tintColor: UIColor, selected: Bool) {
        var configuration = button.configuration
        configuration?.baseForegroundColor = tintColor
        configuration?.baseBackgroundColor = selected ? tintColor.withAlphaComponent(0.12) : .clear
        configuration?.cornerStyle = .capsule
        button.configuration = configuration
    }

    private func makeBadge(text: String, tintColor: UIColor) -> UIView {
        let label = InsetLabel(insets: UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7))
        label.text = text
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = tintColor
        label.backgroundColor = tintColor.withAlphaComponent(0.12)
        label.layer.cornerRadius = 9
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        return label
    }

    @objc private func didTapReply() {
        onReplyTapped?()
    }

    @objc private func didTapLike() {
        onLikeTapped?()
    }

    @objc private func didTapDislike() {
        onDislikeTapped?()
    }

    @objc private func didTapMore() {
        onMoreTapped?()
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
