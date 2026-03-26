import UIKit

final class ProfileEditRootView: UIView {

    let nicknameFieldView = AuthInputFieldView(
        title: "닉네임",
        placeholder: "닉네임 입력",
        systemImageName: "person"
    )
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
        label.text = "닉네임과 프로필 사진을 수정할 수 있어요."
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
        label.text = "사진은 저장 후 반영됩니다."
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
        [photoSectionStackView, nicknameFieldView, saveButton].forEach {
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
        photoActionConfiguration.title = "사진 추가"
        photoActionConfiguration.attributedTitle = AttributedString(
            "사진 추가",
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ])
        )
        photoActionButton.configuration = photoActionConfiguration

        var removeConfiguration = UIButton.Configuration.plain()
        removeConfiguration.baseForegroundColor = .gpCoral
        removeConfiguration.title = "사진 제거"
        removeConfiguration.attributedTitle = AttributedString(
            "사진 제거",
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ])
        )
        removePhotoButton.configuration = removeConfiguration
        removePhotoButton.isHidden = true

        var saveConfiguration = UIButton.Configuration.filled()
        saveConfiguration.title = "저장"
        saveConfiguration.baseBackgroundColor = .gpPrimary
        saveConfiguration.baseForegroundColor = .gpOnPrimary
        saveConfiguration.cornerStyle = .capsule
        saveConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        saveConfiguration.attributedTitle = AttributedString(
            "저장",
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ])
        )
        saveButton.configuration = saveConfiguration
    }

    private func applyDynamicLayerColors() {
        formCardView.layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }
}
