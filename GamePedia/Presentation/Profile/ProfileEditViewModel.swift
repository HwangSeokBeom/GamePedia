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
    private let profileBadgeSelectionStore: ProfileBadgeSelectionStore
    private var cancellables = Set<AnyCancellable>()

    init(
        authenticatedUser: AuthUser,
        initialSelectedTitleKey: String? = nil,
        updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase,
        uploadCurrentUserProfileImageUseCase: UploadCurrentUserProfileImageUseCase,
        removeCurrentUserProfileImageUseCase: RemoveCurrentUserProfileImageUseCase,
        profileBadgeSelectionStore: ProfileBadgeSelectionStore = .shared
    ) {
        self.state = ProfileEditState(
            authenticatedUser: authenticatedUser,
            selectedTitleKey: initialSelectedTitleKey
        )
        self.updateCurrentUserProfileUseCase = updateCurrentUserProfileUseCase
        self.uploadCurrentUserProfileImageUseCase = uploadCurrentUserProfileImageUseCase
        self.removeCurrentUserProfileImageUseCase = removeCurrentUserProfileImageUseCase
        self.profileBadgeSelectionStore = profileBadgeSelectionStore
        print("[ProfileEdit] initial selectedTitleKey=\(initialSelectedTitleKey ?? "nil")")
        apply(.setNicknameValidationMessage(nicknameValidationMessage(for: authenticatedUser.nickname)))
    }

    func send(_ intent: ProfileEditIntent) {
        switch intent {
        case .nicknameChanged(let nickname):
            apply(.setNickname(nickname))
            apply(.setError(nil))
            apply(.setSuccessMessage(nil))
            apply(.setNicknameValidationMessage(nicknameValidationMessage(for: nickname)))
        case .badgeSelectionToggled(let badgeTitle):
            toggleBadgeSelection(badgeTitle)
            apply(.setError(nil))
            apply(.setSuccessMessage(nil))
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
        let selectedTitleKey = state.selectedTitleKey
        let selectedTitleKeys = selectedTitleKey.map { [$0] } ?? []
        let selectedTitle = profileBadgeSelectionStore.badgeTitle(for: selectedTitleKey)
        print("[ProfileEdit] save tapped")
        print("[ProfileEdit] selectedTitleKey=\(selectedTitleKey ?? "nil")")
        apply(.setNickname(trimmedNickname))
        apply(.setNicknameValidationMessage(nicknameValidationMessage(for: trimmedNickname)))

        guard state.isSaveEnabled else { return }

        apply(.setSaving(true))
        apply(.setError(nil))
        apply(.setSuccessMessage(nil))

        let shouldUpdateProfile = trimmedNickname != state.originalUser.nickname
            || selectedTitleKey != state.originalSelectedTitleKey

        let basePublisher: AnyPublisher<AuthUser, AuthError>
        if shouldUpdateProfile {
            print("[ProfileEdit] save payload selectedTitleKeys=\(selectedTitleKeys)")
            basePublisher = updateCurrentUserProfileUseCase.execute(
                nickname: trimmedNickname,
                selectedTitleKeys: selectedTitleKeys
            )
                .eraseToAnyPublisher()
        } else {
            print("[ProfileEdit] save payload selectedTitleKeys=\(selectedTitleKeys)")
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
                        switch error {
                        case .nicknameAlreadyExists:
                            self.apply(.setNicknameValidationMessage(error.errorDescription))
                            self.apply(.setError(nil))
                        case .server(let code, _) where code.uppercased() == "CONFLICT":
                            self.apply(.setNicknameValidationMessage(AuthError.nicknameAlreadyExists.errorDescription))
                            self.apply(.setError(nil))
                        default:
                            self.apply(
                                .setError(
                                    error.errorDescription
                                    ?? "프로필을 저장하지 못했습니다. 잠시 후 다시 시도해주세요."
                                )
                            )
                        }
                    }
                },
                receiveValue: { [weak self] authenticatedUser in
                    guard let self else { return }

                    print(
                        """
                        [ProfileEdit] saveSuccess \
                        userId=\(authenticatedUser.id) \
                        hasProfileImage=\((authenticatedUser.profileImageUrl?.isEmpty == false)) \
                        selectedTitleKey=\(selectedTitleKey ?? "nil")
                        """
                    )

                    self.apply(.setAuthenticatedUser(authenticatedUser))
                    NotificationCenter.default.post(
                        name: .currentUserProfileDidChange,
                        object: nil,
                        userInfo: [
                            ProfileChangeUserInfoKey.userId: authenticatedUser.id,
                            ProfileChangeUserInfoKey.selectedTitleKey: selectedTitleKey as Any,
                            ProfileChangeUserInfoKey.selectedTitle: selectedTitle as Any
                        ]
                    )
                    self.apply(.setSuccessMessage("프로필을 저장했어요."))
                }
            )
            .store(in: &cancellables)
    }

    private func toggleBadgeSelection(_ badgeTitle: String) {
        let selectedTitleKey = profileBadgeSelectionStore.selectedTitleKey(for: badgeTitle)
        print("[ProfileEdit] tapped selectedTitleKey=\(selectedTitleKey ?? "nil")")
        apply(.setSelectedTitleKey(selectedTitleKey))
    }

    private func nicknameValidationMessage(for nickname: String) -> String? {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else { return "닉네임을 입력해주세요." }
        guard trimmedNickname.count >= 2 else { return "닉네임은 2자 이상이어야 해요." }
        guard trimmedNickname.count <= 30 else { return "닉네임은 30자 이하로 입력해주세요." }
        return nil
    }
}
