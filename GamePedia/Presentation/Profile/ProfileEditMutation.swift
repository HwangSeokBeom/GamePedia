import Foundation

enum ProfileEditMutation {
    case setNickname(String)
    case setSelectedTitleKey(String?)
    case setNicknameValidationMessage(String?)
    case setSelectedImage(ProfileImageDraft?)
    case setPhotoRemoved(Bool)
    case setSaving(Bool)
    case setAuthenticatedUser(AuthUser)
    case setError(String?)
    case setSuccessMessage(String?)
}
