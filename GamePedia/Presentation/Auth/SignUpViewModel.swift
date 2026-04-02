import Combine
import Foundation

final class SignUpViewModel {

    struct State {
        var email: String = ""
        var password: String = ""
        var confirmPassword: String = ""
        var nickname: String = ""
        var emailValidationMessage: String?
        var passwordValidationMessage: String?
        var confirmPasswordValidationMessage: String?
        var nicknameValidationMessage: String?
        var isLoading: Bool = false
        var isSignUpEnabled: Bool = false
        var errorMessage: String?
    }

    enum Intent {
        case emailChanged(String)
        case passwordChanged(String)
        case confirmPasswordChanged(String)
        case nicknameChanged(String)
        case signUpTapped
        case loginTapped
    }

    enum Route {
        case showLogin
        case authenticated
    }

    private(set) var state: State = State() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((State) -> Void)?
    var onRoute: ((Route) -> Void)?

    private let signUpUseCase: SignUpUseCase
    private var cancellables = Set<AnyCancellable>()

    init(signUpUseCase: SignUpUseCase) {
        self.signUpUseCase = signUpUseCase
    }

    func send(_ intent: Intent) {
        switch intent {
        case .emailChanged(let email):
            state.email = email
            state.errorMessage = nil
            state.emailValidationMessage = emailValidationMessage(for: email)
            updateSignUpEnabledState()

        case .passwordChanged(let password):
            state.password = password
            state.errorMessage = nil
            state.passwordValidationMessage = passwordValidationMessage(for: password)
            state.confirmPasswordValidationMessage = confirmPasswordValidationMessage(
                password: password,
                confirmPassword: state.confirmPassword
            )
            updateSignUpEnabledState()

        case .confirmPasswordChanged(let confirmPassword):
            state.confirmPassword = confirmPassword
            state.errorMessage = nil
            state.confirmPasswordValidationMessage = confirmPasswordValidationMessage(
                password: state.password,
                confirmPassword: confirmPassword
            )
            updateSignUpEnabledState()

        case .nicknameChanged(let nickname):
            state.nickname = nickname
            state.errorMessage = nil
            state.nicknameValidationMessage = nicknameValidationMessage(for: nickname)
            updateSignUpEnabledState()

        case .signUpTapped:
            signUp()

        case .loginTapped:
            onRoute?(.showLogin)
        }
    }

    private func signUp() {
        let trimmedEmail = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNickname = state.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        state.email = trimmedEmail
        state.nickname = trimmedNickname
        state.emailValidationMessage = emailValidationMessage(for: trimmedEmail)
        state.passwordValidationMessage = passwordValidationMessage(for: state.password)
        state.confirmPasswordValidationMessage = confirmPasswordValidationMessage(
            password: state.password,
            confirmPassword: state.confirmPassword
        )
        state.nicknameValidationMessage = nicknameValidationMessage(for: trimmedNickname)
        updateSignUpEnabledState()

        guard state.isSignUpEnabled else {
            return
        }

        state.isLoading = true
        state.errorMessage = nil
        updateSignUpEnabledState()

        signUpUseCase.execute(
            email: trimmedEmail,
            password: state.password,
            nickname: trimmedNickname
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                self.state.isLoading = false
                self.updateSignUpEnabledState()

                if case .failure(let error) = completion {
                    self.handleSignUpFailure(error)
                }
            },
            receiveValue: { [weak self] _ in
                self?.onRoute?(.authenticated)
            }
        )
        .store(in: &cancellables)
    }

    private func updateSignUpEnabledState() {
        state.isSignUpEnabled = isValidEmail(state.email)
            && isValidPassword(state.password)
            && isValidConfirmPassword(password: state.password, confirmPassword: state.confirmPassword)
            && isValidNickname(state.nickname)
            && !state.isLoading
    }

    private func handleSignUpFailure(_ error: AuthError) {
        switch error {
        case .emailAlreadyExists:
            state.emailValidationMessage = error.errorDescription
        case .nicknameAlreadyExists:
            state.nicknameValidationMessage = error.errorDescription
        case .server(let code, _) where code.uppercased() == "CONFLICT":
            state.nicknameValidationMessage = AuthError.nicknameAlreadyExists.errorDescription
        default:
            state.errorMessage = error.errorDescription
        }
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

    private func confirmPasswordValidationMessage(password: String, confirmPassword: String) -> String? {
        guard !confirmPassword.isEmpty else { return nil }
        return isValidConfirmPassword(password: password, confirmPassword: confirmPassword)
            ? nil
            : AuthError.passwordMismatch.errorDescription
    }

    private func nicknameValidationMessage(for nickname: String) -> String? {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else { return nil }
        return isValidNickname(trimmedNickname) ? nil : AuthError.emptyNickname.errorDescription
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

    private func isValidConfirmPassword(password: String, confirmPassword: String) -> Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    private func isValidNickname(_ nickname: String) -> Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
