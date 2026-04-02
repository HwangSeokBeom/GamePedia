import UIKit

final class SignUpViewController: BaseViewController<SignUpRootView, SignUpViewModel.State> {

    private let viewModel: SignUpViewModel
    private var lastPresentedErrorMessage: String?

    var onBackRequested: (() -> Void)?
    var onLoginRequested: (() -> Void)?
    var onSignUpRequested: (() -> Void)?

    init(
        rootView: SignUpRootView = SignUpRootView(),
        viewModel: SignUpViewModel
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextPrimary)
        configureNavigationItem()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        setupKeyboardDismissal()
        rootView.setUsesSystemNavigationBar(true)
        bindViewModel()
        render(viewModel.state)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "회원가입"
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.backButtonDisplayMode = .minimal
        }
    }

    private func setupActions() {
        rootView.emailFieldView.textField.addTarget(self, action: #selector(emailDidChange), for: .editingChanged)
        rootView.nicknameFieldView.textField.addTarget(self, action: #selector(nicknameDidChange), for: .editingChanged)
        rootView.passwordFieldView.textField.addTarget(self, action: #selector(passwordDidChange), for: .editingChanged)
        rootView.confirmPasswordFieldView.textField.addTarget(self, action: #selector(confirmPasswordDidChange), for: .editingChanged)
        rootView.backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        rootView.loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)
        rootView.signUpButton.addTarget(self, action: #selector(didTapSignUp), for: .touchUpInside)
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
            case .showLogin:
                self?.onLoginRequested?()
            case .authenticated:
                self?.onSignUpRequested?()
            }
        }
    }

    override func render(_ state: SignUpViewModel.State) {
        rootView.emailFieldView.setValidationState(
            state.emailValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )
        rootView.nicknameFieldView.setValidationState(
            state.nicknameValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )
        rootView.passwordFieldView.setValidationState(
            state.passwordValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )
        rootView.confirmPasswordFieldView.setValidationState(
            state.confirmPasswordValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )

        rootView.signUpButton.isEnabled = state.isSignUpEnabled
        rootView.signUpButton.alpha = state.isSignUpEnabled ? 1 : 0.6

        var signUpButtonConfiguration = rootView.signUpButton.configuration
        signUpButtonConfiguration?.showsActivityIndicator = state.isLoading
        rootView.signUpButton.configuration = signUpButtonConfiguration

        let isInputEnabled = !state.isLoading
        rootView.emailFieldView.textField.isEnabled = isInputEnabled
        rootView.nicknameFieldView.textField.isEnabled = isInputEnabled
        rootView.passwordFieldView.textField.isEnabled = isInputEnabled
        rootView.confirmPasswordFieldView.textField.isEnabled = isInputEnabled
        rootView.loginButton.isEnabled = isInputEnabled

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            showErrorAlert(message: errorMessage)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "회원가입 실패", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    @objc
    private func emailDidChange() {
        viewModel.send(.emailChanged(rootView.emailFieldView.textField.text ?? ""))
    }

    @objc
    private func nicknameDidChange() {
        viewModel.send(.nicknameChanged(rootView.nicknameFieldView.textField.text ?? ""))
    }

    @objc
    private func passwordDidChange() {
        viewModel.send(.passwordChanged(rootView.passwordFieldView.textField.text ?? ""))
    }

    @objc
    private func confirmPasswordDidChange() {
        viewModel.send(.confirmPasswordChanged(rootView.confirmPasswordFieldView.textField.text ?? ""))
    }

    @objc
    private func didTapBack() {
        if let onBackRequested {
            onBackRequested()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc
    private func didTapLogin() {
        view.endEditing(true)
        viewModel.send(.loginTapped)
    }

    @objc
    private func didTapSignUp() {
        view.endEditing(true)
        viewModel.send(.signUpTapped)
    }

    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
    }
}
