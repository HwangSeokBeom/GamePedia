import Combine
import Foundation

final class ResetPasswordViewModel {

    struct State {
        var token: String
        var password: String = ""
        var confirmPassword: String = ""
        var tokenValidationMessage: String?
        var passwordValidationMessage: String?
        var confirmPasswordValidationMessage: String?
        var isLoading: Bool = false
        var isSubmitEnabled: Bool = false
        var successMessage: String?
        var errorMessage: String?
    }

    enum Intent {
        case tokenChanged(String)
        case passwordChanged(String)
        case confirmPasswordChanged(String)
        case submitTapped
        case didAcknowledgeSuccess
    }

    enum Route {
        case showLogin
    }

    private(set) var state: State {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((State) -> Void)?
    var onRoute: ((Route) -> Void)?

    private let resetPasswordUseCase: ResetPasswordUseCase
    private var cancellables = Set<AnyCancellable>()

    init(
        token: String?,
        resetPasswordUseCase: ResetPasswordUseCase
    ) {
        self.state = State(token: token ?? "")
        self.resetPasswordUseCase = resetPasswordUseCase
        self.state.tokenValidationMessage = tokenValidationMessage(for: self.state.token)
        self.state.isSubmitEnabled = false
    }

    func send(_ intent: Intent) {
        switch intent {
        case .tokenChanged(let token):
            state.token = token
            state.errorMessage = nil
            state.successMessage = nil
            state.tokenValidationMessage = tokenValidationMessage(for: token)
            updateSubmitEnabledState()
        case .passwordChanged(let password):
            state.password = password
            state.errorMessage = nil
            state.successMessage = nil
            state.passwordValidationMessage = passwordValidationMessage(for: password)
            state.confirmPasswordValidationMessage = confirmPasswordValidationMessage(
                password: password,
                confirmPassword: state.confirmPassword
            )
            updateSubmitEnabledState()
        case .confirmPasswordChanged(let confirmPassword):
            state.confirmPassword = confirmPassword
            state.errorMessage = nil
            state.successMessage = nil
            state.confirmPasswordValidationMessage = confirmPasswordValidationMessage(
                password: state.password,
                confirmPassword: confirmPassword
            )
            updateSubmitEnabledState()
        case .submitTapped:
            submit()
        case .didAcknowledgeSuccess:
            state.successMessage = nil
            onRoute?(.showLogin)
        }
    }

    private func submit() {
        let trimmedToken = state.token.trimmingCharacters(in: .whitespacesAndNewlines)
        state.token = trimmedToken
        state.tokenValidationMessage = trimmedToken.isEmpty
            ? AuthError.emptyPasswordResetToken.errorDescription
            : tokenValidationMessage(for: trimmedToken)
        state.passwordValidationMessage = passwordValidationMessage(for: state.password)
        state.confirmPasswordValidationMessage = confirmPasswordValidationMessage(
            password: state.password,
            confirmPassword: state.confirmPassword
        )
        updateSubmitEnabledState()

        guard state.isSubmitEnabled else { return }

        state.isLoading = true
        state.errorMessage = nil
        state.successMessage = nil
        updateSubmitEnabledState()

        resetPasswordUseCase.execute(token: trimmedToken, newPassword: state.password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.state.isLoading = false
                    self.updateSubmitEnabledState()

                    if case .failure(let error) = completion {
                        switch error {
                        case .passwordResetTokenInvalid:
                            self.state.tokenValidationMessage = error.errorDescription
                        case .passwordResetTokenExpired:
                            self.state.tokenValidationMessage = error.errorDescription
                        case .passwordResetTokenUsed:
                            self.state.tokenValidationMessage = error.errorDescription
                        default:
                            self.state.errorMessage = error.errorDescription
                        }
                    }
                },
                receiveValue: { [weak self] in
                    self?.state.successMessage = L10n.tr("Localizable", "auth.resetPassword.success")
                }
            )
            .store(in: &cancellables)
    }

    private func updateSubmitEnabledState() {
        state.isSubmitEnabled = isValidToken(state.token)
            && isValidPassword(state.password)
            && isValidConfirmPassword(password: state.password, confirmPassword: state.confirmPassword)
            && !state.isLoading
    }

    private func tokenValidationMessage(for token: String) -> String? {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return nil }
        return isValidToken(trimmedToken) ? nil : AuthError.emptyPasswordResetToken.errorDescription
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

    private func isValidToken(_ token: String) -> Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    private func isValidConfirmPassword(password: String, confirmPassword: String) -> Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }
}
