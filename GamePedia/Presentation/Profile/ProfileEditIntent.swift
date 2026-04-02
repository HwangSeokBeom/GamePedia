import Foundation

enum ProfileEditIntent {
    case nicknameChanged(String)
    case badgeSelectionToggled(String)
    case selectedImage(ProfileImageDraft)
    case removePhotoTapped
    case saveTapped
    case didAcknowledgeSuccess
}

enum ProfileEditRoute {
    case completed
}
