import UIKit

final class ProfileEditRootView: UIView {

    let nicknameFieldView = AuthInputFieldView(
        title: L10n.Profile.Edit.nicknameTitle,
        placeholder: L10n.Profile.Edit.nicknamePlaceholder,
        systemImageName: "person"
    )
    private(set) var badgeButtons: [ProfileBadgeOptionButton] = []
    let photoActionButton = UIButton(type: .system)
    let removePhotoButton = UIButton(type: .system)
    let saveButton = UIButton(type: .system)

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Profile.Edit.subtitle
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let formCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .gpSurfaceElevated
        imageView.layer.cornerRadius = 48
        imageView.layer.masksToBounds = true
        imageView.tintColor = .gpTextTertiary
        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let photoHelperLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Profile.Edit.photoPending
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let formStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let photoSectionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let badgeSelectionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Profile.Edit.badgeTitle
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let badgeSelectionHelperLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.Profile.Edit.badgeHelper
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let badgeSelectionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let badgeSelectionSectionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
        configureControls()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupLayout()
        configureControls()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyDynamicLayerColors()
    }

    func render(_ state: ProfileEditState) {
        let placeholderImage = UIImage(systemName: "person.fill")

        if let previewImage = state.previewImage {
            avatarView.cancelLoad()
            avatarView.image = previewImage
            avatarView.contentMode = .scaleAspectFill
        } else {
            avatarView.contentMode = state.profileImageURL == nil ? .center : .scaleAspectFill
            avatarView.loadImage(url: state.profileImageURL, placeholder: placeholderImage)
        }

        var photoActionConfiguration = photoActionButton.configuration
        photoActionConfiguration?.title = state.photoActionTitle
        photoActionConfiguration?.attributedTitle = AttributedString(
            state.photoActionTitle,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ])
        )
        photoActionButton.configuration = photoActionConfiguration
        removePhotoButton.isHidden = !state.showsRemovePhotoButton
        updateBadgeButtons(selectedTitleKey: state.selectedTitleKey)

        saveButton.isEnabled = state.isSaveEnabled
        saveButton.alpha = state.isSaveEnabled ? 1 : 0.6
        var saveButtonConfiguration = saveButton.configuration
        saveButtonConfiguration?.showsActivityIndicator = state.isSaving
        saveButton.configuration = saveButtonConfiguration
    }

    private func setupView() {
        backgroundColor = .gpBackground

        addSubview(scrollView)
        scrollView.addSubview(contentView)

        [subtitleLabel, formCardView].forEach { contentView.addSubview($0) }
        formCardView.addSubview(formStackView)

        [avatarView, photoActionButton, removePhotoButton, photoHelperLabel].forEach {
            photoSectionStackView.addArrangedSubview($0)
        }
        [badgeSelectionTitleLabel, badgeSelectionHelperLabel, badgeSelectionStackView].forEach {
            badgeSelectionSectionStackView.addArrangedSubview($0)
        }

        ProfileBadgeSelectionStore.availableBadgeTitles.forEach { badgeTitle in
            let button = ProfileBadgeOptionButton(title: badgeTitle)
            badgeButtons.append(button)
            badgeSelectionStackView.addArrangedSubview(button)
        }

        [photoSectionStackView, nicknameFieldView, badgeSelectionSectionStackView, saveButton].forEach {
            formStackView.addArrangedSubview($0)
        }
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            formCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            formCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            formCardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),

            formStackView.topAnchor.constraint(equalTo: formCardView.topAnchor, constant: 24),
            formStackView.leadingAnchor.constraint(equalTo: formCardView.leadingAnchor, constant: 20),
            formStackView.trailingAnchor.constraint(equalTo: formCardView.trailingAnchor, constant: -20),
            formStackView.bottomAnchor.constraint(equalTo: formCardView.bottomAnchor, constant: -20),

            avatarView.widthAnchor.constraint(equalToConstant: 96),
            avatarView.heightAnchor.constraint(equalToConstant: 96),

            photoActionButton.heightAnchor.constraint(equalToConstant: 44),
            photoHelperLabel.widthAnchor.constraint(lessThanOrEqualTo: formStackView.widthAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        applyDynamicLayerColors()
    }

    private func configureControls() {
        nicknameFieldView.textField.textContentType = .nickname

        var photoActionConfiguration = UIButton.Configuration.tinted()
        photoActionConfiguration.baseBackgroundColor = UIColor.gpPrimary.withAlphaComponent(0.16)
        photoActionConfiguration.baseForegroundColor = .gpPrimary
        photoActionConfiguration.cornerStyle = .capsule
        photoActionConfiguration.image = UIImage(systemName: "photo.on.rectangle")
        photoActionConfiguration.imagePadding = 8
        photoActionConfiguration.imagePlacement = .leading
        photoActionConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        photoActionConfiguration.title = L10n.Profile.Action.addPhoto
        photoActionConfiguration.attributedTitle = AttributedString(
            L10n.Profile.Action.addPhoto,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ])
        )
        photoActionButton.configuration = photoActionConfiguration

        var removeConfiguration = UIButton.Configuration.plain()
        removeConfiguration.baseForegroundColor = .gpCoral
        removeConfiguration.title = L10n.Profile.Action.removePhoto
        removeConfiguration.attributedTitle = AttributedString(
            L10n.Profile.Action.removePhoto,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ])
        )
        removePhotoButton.configuration = removeConfiguration
        removePhotoButton.isHidden = true

        var saveConfiguration = UIButton.Configuration.filled()
        saveConfiguration.title = L10n.Common.Button.save
        saveConfiguration.baseBackgroundColor = .gpPrimary
        saveConfiguration.baseForegroundColor = .gpOnPrimary
        saveConfiguration.cornerStyle = .capsule
        saveConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        saveConfiguration.attributedTitle = AttributedString(
            L10n.Common.Button.save,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ])
        )
        saveButton.configuration = saveConfiguration
    }

    private func applyDynamicLayerColors() {
        formCardView.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }

    private func updateBadgeButtons(selectedTitleKey: String?) {
        badgeButtons.forEach { button in
            button.applySelectionStyle(isSelected: button.titleKey == selectedTitleKey)
        }
    }
}

final class ProfileBadgeOptionButton: UIButton {
    let badgeTitle: String
    let titleKey: String?

    init(title: String) {
        self.badgeTitle = title
        self.titleKey = ProfileBadgeSelectionStore.shared.selectedTitleKey(for: title)
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            return attributes
        }
        self.configuration = configuration
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applySelectionStyle(isSelected: Bool) {
        var configuration = configuration
        configuration?.baseBackgroundColor = isSelected ? UIColor.gpPrimary.withAlphaComponent(0.18) : UIColor.gpSurfaceElevated
        configuration?.baseForegroundColor = isSelected ? .gpPrimaryLight : .gpTextSecondary
        self.configuration = configuration
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = (isSelected ? UIColor.gpPrimary.withAlphaComponent(0.32) : UIColor.gpSeparator.withAlphaComponent(0.22)).cgColor
    }
}
