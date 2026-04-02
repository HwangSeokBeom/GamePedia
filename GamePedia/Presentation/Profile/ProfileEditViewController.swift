import PhotosUI
import UIKit

final class ProfileEditViewController: BaseViewController<ProfileEditRootView, ProfileEditState> {

    private let viewModel: ProfileEditViewModel
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?

    var onCompleted: (() -> Void)?

    init(
        rootView: ProfileEditRootView = ProfileEditRootView(),
        viewModel: ProfileEditViewModel
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        setupKeyboardDismissal()
        bindViewModel()
        render(viewModel.state)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "프로필 편집"
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.backButtonDisplayMode = .minimal
        }
    }

    private func setupActions() {
        rootView.nicknameFieldView.textField.addTarget(self, action: #selector(nicknameDidChange), for: .editingChanged)
        rootView.photoActionButton.addTarget(self, action: #selector(didTapPhotoAction), for: .touchUpInside)
        rootView.removePhotoButton.addTarget(self, action: #selector(didTapRemovePhoto), for: .touchUpInside)
        rootView.saveButton.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
    }

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }

        viewModel.onRoute = { [weak self] route in
            switch route {
            case .completed:
                self?.onCompleted?()
            }
        }
    }

    override func render(_ state: ProfileEditState) {
        if rootView.nicknameFieldView.textField.text != state.nickname {
            rootView.nicknameFieldView.textField.text = state.nickname
        }

        rootView.nicknameFieldView.setValidationState(
            state.nicknameValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )
        rootView.render(state)

        let isInputEnabled = !state.isSaving
        rootView.nicknameFieldView.textField.isEnabled = isInputEnabled
        rootView.photoActionButton.isEnabled = isInputEnabled
        rootView.removePhotoButton.isEnabled = isInputEnabled

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            showAlert(title: "오류", message: errorMessage)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }

        if let successMessage = state.successMessage,
           successMessage != lastPresentedSuccessMessage {
            lastPresentedSuccessMessage = successMessage
            let alert = UIAlertController(title: nil, message: successMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
                self?.viewModel.send(.didAcknowledgeSuccess)
            })
            present(alert, animated: true)
        } else if state.successMessage == nil {
            lastPresentedSuccessMessage = nil
        }
    }

    @objc private func nicknameDidChange() {
        viewModel.send(.nicknameChanged(rootView.nicknameFieldView.textField.text ?? ""))
    }

    @objc private func didTapPhotoAction() {
        view.endEditing(true)

        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "사진 보관함", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })
        if viewModel.state.showsRemovePhotoButton {
            actionSheet.addAction(UIAlertAction(title: "사진 제거", style: .destructive) { [weak self] _ in
                self?.viewModel.send(.removePhotoTapped)
            })
        }
        actionSheet.addAction(UIAlertAction(title: "취소", style: .cancel))

        if let popoverPresentationController = actionSheet.popoverPresentationController {
            popoverPresentationController.sourceView = rootView.photoActionButton
            popoverPresentationController.sourceRect = rootView.photoActionButton.bounds
        }

        present(actionSheet, animated: true)
    }

    @objc private func didTapRemovePhoto() {
        view.endEditing(true)
        viewModel.send(.removePhotoTapped)
    }

    @objc private func didTapSave() {
        view.endEditing(true)
        viewModel.send(.saveTapped)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        present(pickerViewController, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

extension ProfileEditViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }
        guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.showAlert(title: "오류", message: error.localizedDescription)
                }
                return
            }

            guard let image = object as? UIImage,
                  let imageDraft = Self.makeImageDraft(from: image) else {
                DispatchQueue.main.async {
                    self.showAlert(title: "오류", message: "이미지를 불러오지 못했습니다.")
                }
                return
            }

            DispatchQueue.main.async {
                self.viewModel.send(.selectedImage(imageDraft))
            }
        }
    }

    private static func makeImageDraft(from image: UIImage) -> ProfileImageDraft? {
        let resizedImage = image.resizedForProfileUpload(maxDimension: 1024)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.82) else {
            return nil
        }

        return ProfileImageDraft(
            previewImage: resizedImage,
            imageData: imageData,
            fileName: "profile.jpg",
            mimeType: "image/jpeg"
        )
    }
}

private extension UIImage {
    func resizedForProfileUpload(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scaleRatio = maxDimension / longestSide
        let targetSize = CGSize(
            width: size.width * scaleRatio,
            height: size.height * scaleRatio
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
