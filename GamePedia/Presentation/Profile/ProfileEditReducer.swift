import Foundation

enum ProfileEditReducer {
    static func reduce(_ state: ProfileEditState, _ mutation: ProfileEditMutation) -> ProfileEditState {
        var state = state

        switch mutation {
        case .setNickname(let nickname):
            state.nickname = nickname
        case .setNicknameValidationMessage(let message):
            state.nicknameValidationMessage = message
        case .setSelectedImage(let imageDraft):
            state.selectedImageDraft = imageDraft
        case .setPhotoRemoved(let isPhotoRemoved):
            state.isPhotoRemoved = isPhotoRemoved
        case .setSaving(let isSaving):
            state.isSaving = isSaving
        case .setAuthenticatedUser(let authenticatedUser):
            state = ProfileEditState(authenticatedUser: authenticatedUser)
        case .setError(let message):
            state.errorMessage = message
        case .setSuccessMessage(let message):
            state.successMessage = message
        }

        return state
    }
}
