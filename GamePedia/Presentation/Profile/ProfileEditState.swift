import Foundation
import UIKit

struct ProfileEditState {
    let originalUser: AuthUser
    let originalSelectedTitleKey: String?
    var nickname: String
    var selectedTitleKey: String?
    var nicknameValidationMessage: String?
    var selectedImageDraft: ProfileImageDraft?
    var isPhotoRemoved: Bool = false
    var isSaving: Bool = false
    var successMessage: String?
    var errorMessage: String?

    init(authenticatedUser: AuthUser, selectedTitleKey: String? = nil) {
        self.originalUser = authenticatedUser
        self.originalSelectedTitleKey = selectedTitleKey
        self.nickname = authenticatedUser.nickname
        self.selectedTitleKey = selectedTitleKey
    }

    var availableBadgeTitles: [String] {
        ProfileBadgeSelectionStore.availableBadgeTitles
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
        hasExistingProfileImage ? L10n.Profile.Action.changePhoto : L10n.Profile.Action.addPhoto
    }

    var showsRemovePhotoButton: Bool {
        hasExistingProfileImage
    }

    var hasPendingChanges: Bool {
        trimmedNickname != originalUser.nickname
            || selectedImageDraft != nil
            || isPhotoRemoved
            || selectedTitleKey != originalSelectedTitleKey
    }

    var isSaveEnabled: Bool {
        nicknameValidationMessage == nil
            && !trimmedNickname.isEmpty
            && hasPendingChanges
            && !isSaving
    }
}
