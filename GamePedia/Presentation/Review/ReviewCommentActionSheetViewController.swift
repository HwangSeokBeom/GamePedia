import UIKit

final class ReviewCommentActionSheetViewController: UIViewController {
    struct Context {
        struct Action {
            enum Kind {
                case reply
                case edit
                case delete
                case report
            }

            let kind: Kind
            let title: String
            let systemImageName: String
            let tintColor: UIColor
        }

        let title: String
        let metadata: String
        let avatarURL: URL?
        let avatarText: String
        let avatarBackgroundColor: UIColor
        let actions: [Action]
    }

    var onActionSelected: ((Context.Action.Kind) -> Void)?

    private let context: Context
    private let dimView: UIControl = {
        let control = UIControl()
        control.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        control.alpha = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let sheetContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let handleView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpTextTertiary
        view.layer.cornerRadius = 2
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let avatarInitialLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpAvatarInitialText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        return label
    }()

    private let actionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let cancelButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = L10n.Common.Button.cancel
        configuration.baseForegroundColor = .gpTextPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let button = UIButton(configuration: configuration)
        button.backgroundColor = .gpSurfaceElevated
        button.layer.cornerRadius = 12
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.gpSeparator.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var containerBottomConstraint: NSLayoutConstraint?
    private var sheetContentBottomConstraint: NSLayoutConstraint?
    private var hasAnimatedIn = false

    init(context: Context) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedIn else { return }
        hasAnimatedIn = true
        presentSheet()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        sheetContentBottomConstraint?.constant = -(max(view.safeAreaInsets.bottom, 8))
    }

    private func setup() {
        view.backgroundColor = .clear

        avatarView.addSubview(avatarInitialLabel)
        avatarView.backgroundColor = context.avatarBackgroundColor
        avatarInitialLabel.text = context.avatarText
        avatarView.loadImage(url: context.avatarURL)
        titleLabel.text = context.title
        metadataLabel.text = context.metadata

        dimView.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

        let headerTextStack = UIStackView(arrangedSubviews: [titleLabel, metadataLabel])
        headerTextStack.axis = .vertical
        headerTextStack.spacing = 2

        let headerRow = UIStackView(arrangedSubviews: [avatarView, headerTextStack])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 10
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        context.actions.enumerated().forEach { index, action in
            let button = makeActionButton(for: action)
            button.tag = index
            actionsStackView.addArrangedSubview(button)
        }

        let handleRow = UIView()
        handleRow.translatesAutoresizingMaskIntoConstraints = false
        handleRow.addSubview(handleView)

        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(headerRow)

        let headerDivider = makeDivider()
        let footerDivider = makeDivider()

        let cancelSection = UIView()
        cancelSection.translatesAutoresizingMaskIntoConstraints = false
        cancelSection.addSubview(cancelButton)
        cancelSection.addSubview(footerDivider)

        let stackView = UIStackView(arrangedSubviews: [handleRow, headerContainer, headerDivider, actionsStackView, cancelSection])
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(dimView)
        view.addSubview(sheetContainerView)
        sheetContainerView.addSubview(stackView)

        containerBottomConstraint = sheetContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 360)
        sheetContentBottomConstraint = cancelButton.bottomAnchor.constraint(equalTo: cancelSection.bottomAnchor, constant: -max(view.safeAreaInsets.bottom, 8))
        containerBottomConstraint?.isActive = true
        sheetContentBottomConstraint?.isActive = true

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sheetContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: sheetContainerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: sheetContainerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: sheetContainerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: sheetContainerView.bottomAnchor),

            handleRow.heightAnchor.constraint(equalToConstant: 24),
            handleView.centerXAnchor.constraint(equalTo: handleRow.centerXAnchor),
            handleView.topAnchor.constraint(equalTo: handleRow.topAnchor, constant: 8),
            handleView.widthAnchor.constraint(equalToConstant: 36),
            handleView.heightAnchor.constraint(equalToConstant: 4),

            avatarView.widthAnchor.constraint(equalToConstant: 32),
            avatarView.heightAnchor.constraint(equalToConstant: 32),
            avatarInitialLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarInitialLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            headerRow.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            headerRow.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            headerRow.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),
            headerRow.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -12),

            cancelButton.leadingAnchor.constraint(equalTo: cancelSection.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: cancelSection.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 48),

            footerDivider.topAnchor.constraint(equalTo: cancelSection.topAnchor),
            footerDivider.leadingAnchor.constraint(equalTo: cancelSection.leadingAnchor),
            footerDivider.trailingAnchor.constraint(equalTo: cancelSection.trailingAnchor)
        ])
    }

    private func makeActionButton(for action: Context.Action) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = action.title
        configuration.image = UIImage(
            systemName: action.systemImageName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        )
        configuration.imagePadding = 14
        configuration.baseForegroundColor = action.tintColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        configuration.titleAlignment = .leading

        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        button.addTarget(self, action: #selector(didTapAction(_:)), for: .touchUpInside)
        return button
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = .gpSeparator
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func presentSheet() {
        view.layoutIfNeeded()
        containerBottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut]) {
            self.dimView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    private func dismissSheet(completion: (() -> Void)? = nil) {
        containerBottomConstraint?.constant = 360
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: {
            self.dimView.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: false, completion: completion)
        })
    }

    @objc private func didTapDismiss() {
        dismissSheet()
    }

    @objc private func didTapAction(_ sender: UIButton) {
        guard context.actions.indices.contains(sender.tag) else { return }
        let action = context.actions[sender.tag]
        dismissSheet { [weak self] in
            self?.onActionSelected?(action.kind)
        }
    }
}
