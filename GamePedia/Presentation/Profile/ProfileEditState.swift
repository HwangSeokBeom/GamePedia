import Foundation
import UIKit

struct ProfileEditState {
    let originalUser: AuthUser
    var nickname: String
    var nicknameValidationMessage: String?
    var selectedImageDraft: ProfileImageDraft?
    var isPhotoRemoved: Bool = false
    var isSaving: Bool = false
    var successMessage: String?
    var errorMessage: String?

    init(authenticatedUser: AuthUser) {
        self.originalUser = authenticatedUser
        self.nickname = authenticatedUser.nickname
    }

    var profileImageURL: URL? {
        guard !isPhotoRemoved else { return nil }
        return originalUser.profileImageUrl.flatMap(URL.init(string:))
    }

    var previewImage: UIImage? {
        selectedImageDraft?.previewImage
    }

    var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasExistingProfileImage: Bool {
        previewImage != nil || profileImageURL != nil
    }

    var photoActionTitle: String {
        hasExistingProfileImage ? "사진 변경" : "사진 추가"
    }

    var showsRemovePhotoButton: Bool {
        hasExistingProfileImage
    }

    var hasPendingChanges: Bool {
        trimmedNickname != originalUser.nickname || selectedImageDraft != nil || isPhotoRemoved
    }

    var isSaveEnabled: Bool {
        nicknameValidationMessage == nil
            && !trimmedNickname.isEmpty
            && hasPendingChanges
            && !isSaving
    }
}
