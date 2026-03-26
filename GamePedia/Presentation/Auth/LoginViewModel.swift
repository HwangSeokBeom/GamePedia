import Combine
import Foundation

final class LoginViewModel {

    struct State {
        var email: String = ""
        var password: String = ""
        var emailValidationMessage: String?
        var passwordValidationMessage: String?
        var isLoading: Bool = false
        var isLoginEnabled: Bool = false
        var errorMessage: String?
    }

    enum Intent {
        case emailChanged(String)
        case passwordChanged(String)
        case loginButtonTapped
        case appleLoginSucceeded(AppleLoginCredential)
        case appleLoginFailed(AuthError)
        case googleLoginSucceeded(GoogleLoginCredential)
        case googleLoginFailed(AuthError)
        case signUpTapped
    }

    enum Route {
        case showSignUp
        case authenticated
    }

    private(set) var state: State = State() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((State) -> Void)?
    var onRoute: ((Route) -> Void)?

    private let loginUseCase: LoginUseCase
    private let appleLoginUseCase: AppleLoginUseCase
    private let googleLoginUseCase: GoogleLoginUseCase
    private var cancellables = Set<AnyCancellable>()

    init(
        loginUseCase: LoginUseCase,
        appleLoginUseCase: AppleLoginUseCase,
        googleLoginUseCase: GoogleLoginUseCase
    ) {
        self.loginUseCase = loginUseCase
        self.appleLoginUseCase = appleLoginUseCase
        self.googleLoginUseCase = googleLoginUseCase
    }

    func send(_ intent: Intent) {
        switch intent {
        case .emailChanged(let email):
            state.email = email
            state.errorMessage = nil
            state.emailValidationMessage = emailValidationMessage(for: email)
            updateLoginEnabledState()

        case .passwordChanged(let password):
            state.password = password
            state.errorMessage = nil
            state.passwordValidationMessage = passwordValidationMessage(for: password)
            updateLoginEnabledState()

        case .loginButtonTapped:
            login()

        case .appleLoginSucceeded(let credential):
            loginWithApple(credential: credential)

        case .appleLoginFailed(let error):
            handleAppleLoginFailure(error)

        case .googleLoginSucceeded(let credential):
            loginWithGoogle(credential: credential)

        case .googleLoginFailed(let error):
            handleGoogleLoginFailure(error)

        case .signUpTapped:
            onRoute?(.showSignUp)
        }
    }

    private func login() {
        let trimmedEmail = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        state.email = trimmedEmail
        state.emailValidationMessage = emailValidationMessage(for: trimmedEmail)
        state.passwordValidationMessage = passwordValidationMessage(for: state.password)
        updateLoginEnabledState()

        guard state.isLoginEnabled else {
            return
        }

        state.isLoading = true
        state.errorMessage = nil
        updateLoginEnabledState()

        loginUseCase.execute(email: trimmedEmail, password: state.password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.state.isLoading = false
                    self.updateLoginEnabledState()

                    if case .failure(let error) = completion {
                        self.state.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.onRoute?(.authenticated)
                }
            )
            .store(in: &cancellables)
    }

    private func loginWithApple(credential: AppleLoginCredential) {
        guard !state.isLoading else { return }

        state.isLoading = true
        state.errorMessage = nil
        updateLoginEnabledState()

        appleLoginUseCase.execute(credential: credential)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.state.isLoading = false
                    self.updateLoginEnabledState()

                    if case .failure(let error) = completion,
                       error != .socialLoginCancelled {
                        self.state.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.onRoute?(.authenticated)
                }
            )
            .store(in: &cancellables)
    }

    private func loginWithGoogle(credential: GoogleLoginCredential) {
        guard !state.isLoading else { return }

        state.isLoading = true
        state.errorMessage = nil
        updateLoginEnabledState()

        googleLoginUseCase.execute(credential: credential)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.state.isLoading = false
                    self.updateLoginEnabledState()

                    if case .failure(let error) = completion,
                       error != .socialLoginCancelled {
                        self.state.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.onRoute?(.authenticated)
                }
            )
            .store(in: &cancellables)
    }

    private func handleAppleLoginFailure(_ error: AuthError) {
        guard error != .socialLoginCancelled else { return }
        state.errorMessage = error.errorDescription
    }

    private func handleGoogleLoginFailure(_ error: AuthError) {
        guard error != .socialLoginCancelled else { return }
        state.errorMessage = error.errorDescription
    }

    private func updateLoginEnabledState() {
        state.isLoginEnabled = isValidEmail(state.email)
            && isValidPassword(state.password)
            && !state.isLoading
    }

    private func emailValidationMessage(for email: String) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return nil }
        return isValidEmail(trimmedEmail) ? nil : AuthError.invalidEmailFormat.errorDescription
    }

    private func passwordValidationMessage(for password: String) -> String? {
        guard !password.isEmpty else { return nil }
        return isValidPassword(password) ? nil : AuthError.passwordTooShort.errorDescription
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailPredicate = NSPredicate(
            format: "SELF MATCHES %@",
            "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        )
        return emailPredicate.evaluate(with: trimmedEmail)
    }

    private func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }
}
