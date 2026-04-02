import Combine
import Foundation

final class ProfileEditViewModel {

    private(set) var state: ProfileEditState {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ProfileEditState) -> Void)?
    var onRoute: ((ProfileEditRoute) -> Void)?

    private let updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase
    private let uploadCurrentUserProfileImageUseCase: UploadCurrentUserProfileImageUseCase
    private let removeCurrentUserProfileImageUseCase: RemoveCurrentUserProfileImageUseCase
    private var cancellables = Set<AnyCancellable>()

    init(
        authenticatedUser: AuthUser,
        updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase,
        uploadCurrentUserProfileImageUseCase: UploadCurrentUserProfileImageUseCase,
        removeCurrentUserProfileImageUseCase: RemoveCurrentUserProfileImageUseCase
    ) {
        self.state = ProfileEditState(authenticatedUser: authenticatedUser)
        self.updateCurrentUserProfileUseCase = updateCurrentUserProfileUseCase
        self.uploadCurrentUserProfileImageUseCase = uploadCurrentUserProfileImageUseCase
        self.removeCurrentUserProfileImageUseCase = removeCurrentUserProfileImageUseCase
        apply(.setNicknameValidationMessage(nicknameValidationMessage(for: authenticatedUser.nickname)))
    }

    func send(_ intent: ProfileEditIntent) {
        switch intent {
        case .nicknameChanged(let nickname):
            apply(.setNickname(nickname))
            apply(.setError(nil))
            apply(.setSuccessMessage(nil))
            apply(.setNicknameValidationMessage(nicknameValidationMessage(for: nickname)))
        case .selectedImage(let imageDraft):
            apply(.setSelectedImage(imageDraft))
            apply(.setPhotoRemoved(false))
            apply(.setError(nil))
        case .removePhotoTapped:
            apply(.setSelectedImage(nil))
            apply(.setPhotoRemoved(state.originalUser.profileImageUrl != nil))
            apply(.setError(nil))
        case .saveTapped:
            saveProfile()
        case .didAcknowledgeSuccess:
            apply(.setSuccessMessage(nil))
            onRoute?(.completed)
        }
    }

    private func apply(_ mutation: ProfileEditMutation) {
        state = ProfileEditReducer.reduce(state, mutation)
    }

    private func saveProfile() {
        let trimmedNickname = state.trimmedNickname
        apply(.setNickname(trimmedNickname))
        apply(.setNicknameValidationMessage(nicknameValidationMessage(for: trimmedNickname)))

        guard state.isSaveEnabled else { return }

        apply(.setSaving(true))
        apply(.setError(nil))
        apply(.setSuccessMessage(nil))

        let basePublisher: AnyPublisher<AuthUser, AuthError>
        if trimmedNickname != state.originalUser.nickname {
            basePublisher = updateCurrentUserProfileUseCase.execute(nickname: trimmedNickname)
                .eraseToAnyPublisher()
        } else {
            basePublisher = Just(state.originalUser)
                .setFailureType(to: AuthError.self)
                .eraseToAnyPublisher()
        }

        basePublisher
            .flatMap { [weak self] currentUser -> AnyPublisher<AuthUser, AuthError> in
                guard let self else {
                    return Fail(error: AuthError.invalidResponse).eraseToAnyPublisher()
                }

                if let imageDraft = self.state.selectedImageDraft {
                    return self.uploadCurrentUserProfileImageUseCase.execute(
                        data: imageDraft.imageData,
                        fileName: imageDraft.fileName,
                        mimeType: imageDraft.mimeType
                    )
                    .eraseToAnyPublisher()
                }

                if self.state.isPhotoRemoved {
                    return self.removeCurrentUserProfileImageUseCase.execute()
                        .eraseToAnyPublisher()
                }

                return Just(currentUser)
                    .setFailureType(to: AuthError.self)
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.apply(.setSaving(false))

                    if case .failure(let error) = completion {
                        self.apply(
                            .setError(
                                error.errorDescription
                                ?? "프로필을 저장하지 못했습니다. 잠시 후 다시 시도해주세요."
                            )
                        )
                    }
                },
                receiveValue: { [weak self] authenticatedUser in
                    guard let self else { return }

                    print(
                        """
                        [ProfileEdit] saveSuccess \
                        userId=\(authenticatedUser.id) \
                        hasProfileImage=\((authenticatedUser.profileImageUrl?.isEmpty == false))
                        """
                    )

                    self.apply(.setAuthenticatedUser(authenticatedUser))
                    NotificationCenter.default.post(
                        name: .currentUserProfileDidChange,
                        object: nil,
                        userInfo: [ProfileChangeUserInfoKey.userId: authenticatedUser.id]
                    )
                    self.apply(.setSuccessMessage("프로필을 저장했어요."))
                }
            )
            .store(in: &cancellables)
    }

    private func nicknameValidationMessage(for nickname: String) -> String? {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else { return "닉네임을 입력해주세요." }
        guard trimmedNickname.count >= 2 else { return "닉네임은 2자 이상이어야 해요." }
        guard trimmedNickname.count <= 30 else { return "닉네임은 30자 이하로 입력해주세요." }
        return nil
    }
}
