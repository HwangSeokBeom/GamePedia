import UIKit

final class LoginViewController: BaseViewController<LoginRootView, LoginViewModel.State> {

    private let viewModel: LoginViewModel
    private var lastPresentedErrorMessage: String?

    var onLoginRequested: (() -> Void)?
    var onSignUpRequested: (() -> Void)?
    var onForgotPasswordRequested: (() -> Void)?

    init(
        rootView: LoginRootView = LoginRootView(),
        viewModel: LoginViewModel
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        setupKeyboardDismissal()
        bindViewModel()
        render(viewModel.state)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func setupActions() {
        rootView.emailFieldView.textField.addTarget(self, action: #selector(emailDidChange), for: .editingChanged)
        rootView.passwordFieldView.textField.addTarget(self, action: #selector(passwordDidChange), for: .editingChanged)
        rootView.loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)
        rootView.signUpButton.addTarget(self, action: #selector(didTapSignUp), for: .touchUpInside)
        rootView.forgotPasswordButton.addTarget(self, action: #selector(didTapForgotPassword), for: .touchUpInside)
    }

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func bindViewModel() {
        viewModel.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.render(state)
            }
        }

        viewModel.onRoute = { [weak self] route in
            switch route {
            case .showSignUp:
                self?.onSignUpRequested?()
            case .authenticated:
                self?.onLoginRequested?()
            }
        }
    }

    override func render(_ state: LoginViewModel.State) {
        rootView.emailFieldView.setValidationState(
            state.emailValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )
        rootView.passwordFieldView.setValidationState(
            state.passwordValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )

        rootView.loginButton.isEnabled = state.isLoginEnabled
        rootView.loginButton.alpha = state.isLoginEnabled ? 1 : 0.6

        var loginButtonConfiguration = rootView.loginButton.configuration
        loginButtonConfiguration?.showsActivityIndicator = state.isLoading
        loginButtonConfiguration?.image = nil
        rootView.loginButton.configuration = loginButtonConfiguration

        rootView.emailFieldView.textField.isEnabled = !state.isLoading
        rootView.passwordFieldView.textField.isEnabled = !state.isLoading
        rootView.signUpButton.isEnabled = !state.isLoading
        rootView.forgotPasswordButton.isEnabled = !state.isLoading

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            showErrorAlert(message: errorMessage)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "로그인 실패", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    @objc
    private func emailDidChange() {
        viewModel.send(.emailChanged(rootView.emailFieldView.textField.text ?? ""))
    }

    @objc
    private func passwordDidChange() {
        viewModel.send(.passwordChanged(rootView.passwordFieldView.textField.text ?? ""))
    }

    @objc
    private func didTapLogin() {
        view.endEditing(true)
        viewModel.send(.loginButtonTapped)
    }

    @objc
    private func didTapSignUp() {
        viewModel.send(.signUpTapped)
    }

    @objc
    private func didTapForgotPassword() {
        onForgotPasswordRequested?()
    }

    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
    }
}
