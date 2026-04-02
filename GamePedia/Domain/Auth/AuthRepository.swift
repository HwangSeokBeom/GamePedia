import Foundation
import Combine

protocol AuthRepository {
    func login(email: String, password: String) -> AnyPublisher<AuthSession, AuthError>
    func forgotPassword(email: String) -> AnyPublisher<String, AuthError>
    func resetPassword(token: String, newPassword: String) -> AnyPublisher<Void, AuthError>
    func loginWithApple(credential: AppleLoginCredential) -> AnyPublisher<AuthSession, AuthError>
    func loginWithGoogle(credential: GoogleLoginCredential) -> AnyPublisher<AuthSession, AuthError>

    func signUp(
        email: String,
        password: String,
        nickname: String
    ) -> AnyPublisher<AuthSession, AuthError>

    func refreshSession() -> AnyPublisher<AuthSession, AuthError>
    func fetchCurrentUser() -> AnyPublisher<AuthUser, AuthError>
    func updateCurrentUserProfile(nickname: String) -> AnyPublisher<AuthUser, AuthError>
    func uploadCurrentUserProfileImage(data: Data, fileName: String, mimeType: String) -> AnyPublisher<AuthUser, AuthError>
    func removeCurrentUserProfileImage() -> AnyPublisher<AuthUser, AuthError>
    func logout()
    func deleteAccount() -> AnyPublisher<Void, AuthError>
}
