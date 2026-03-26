import Combine
import Foundation

final class UploadCurrentUserProfileImageUseCase {

    private let authRepository: any AuthRepository

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
    }

    func execute(data: Data, fileName: String, mimeType: String) -> AnyPublisher<AuthUser, AuthError> {
        authRepository.uploadCurrentUserProfileImage(
            data: data,
            fileName: fileName,
            mimeType: mimeType
        )
    }
}
