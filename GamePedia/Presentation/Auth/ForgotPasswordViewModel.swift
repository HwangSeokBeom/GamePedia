import Combine
import Foundation

final class ForgotPasswordViewModel {

    struct State {
        var email: String = ""
        var emailValidationMessage: String?
        var isLoading: Bool = false
        var isSubmitEnabled: Bool = false
        var successMessage: String?
        var errorMessage: String?
    }

    enum Intent {
        case emailChanged(String)
        case submitTapped
        case didTapManualReset
        case didAcknowledgeSuccess
    }

    enum Route {
        case showResetPassword(token: String?)
        case showLogin
    }

    private(set) var state: State = .init() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((State) -> Void)?
    var onRoute: ((Route) -> Void)?

    private let forgotPasswordUseCase: ForgotPasswordUseCase
    private var cancellables = Set<AnyCancellable>()

    init(forgotPasswordUseCase: ForgotPasswordUseCase) {
        self.forgotPasswordUseCase = forgotPasswordUseCase
    }

    func send(_ intent: Intent) {
        switch intent {
        case .emailChanged(let email):
            state.email = email
            state.errorMessage = nil
            state.successMessage = nil
            state.emailValidationMessage = emailValidationMessage(for: email)
            updateSubmitEnabledState()
        case .submitTapped:
            submit()
        case .didTapManualReset:
            onRoute?(.showResetPassword(token: nil))
        case .didAcknowledgeSuccess:
            state.successMessage = nil
            onRoute?(.showLogin)
        }
    }

    private func submit() {
        let trimmedEmail = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
        state.email = trimmedEmail
        state.emailValidationMessage = emailValidationMessage(for: trimmedEmail)
        updateSubmitEnabledState()

        guard state.isSubmitEnabled else { return }

        state.isLoading = true
        state.errorMessage = nil
        state.successMessage = nil
        updateSubmitEnabledState()

        forgotPasswordUseCase.execute(email: trimmedEmail)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.state.isLoading = false
                    self.updateSubmitEnabledState()

                    if case .failure(let error) = completion {
                        self.state.errorMessage = error.errorDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.state.successMessage = "가입된 이메일이라면 비밀번호 재설정 안내를 보냈어요."
                }
            )
            .store(in: &cancellables)
    }

    private func updateSubmitEnabledState() {
        state.isSubmitEnabled = isValidEmail(state.email) && !state.isLoading
    }

    private func emailValidationMessage(for email: String) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return nil }
        return isValidEmail(trimmedEmail) ? nil : AuthError.invalidEmailFormat.errorDescription
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailPredicate = NSPredicate(
            format: "SELF MATCHES %@",
            "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        )
        return emailPredicate.evaluate(with: trimmedEmail)
    }
}
