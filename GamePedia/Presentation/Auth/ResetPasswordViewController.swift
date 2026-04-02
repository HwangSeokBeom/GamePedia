import UIKit

final class ResetPasswordViewController: BaseViewController<ResetPasswordRootView, ResetPasswordViewModel.State> {

    private let viewModel: ResetPasswordViewModel
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?

    var onCompleted: (() -> Void)?

    init(
        rootView: ResetPasswordRootView = ResetPasswordRootView(),
        viewModel: ResetPasswordViewModel
    ) {
        self.viewModel = viewModel
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
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
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "비밀번호 재설정"
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.backButtonDisplayMode = .minimal
        }
    }

    private func setupActions() {
        rootView.tokenFieldView.textField.addTarget(self, action: #selector(tokenDidChange), for: .editingChanged)
        rootView.passwordFieldView.textField.addTarget(self, action: #selector(passwordDidChange), for: .editingChanged)
        rootView.confirmPasswordFieldView.textField.addTarget(self, action: #selector(confirmPasswordDidChange), for: .editingChanged)
        rootView.resetButton.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
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
                self?.onCompleted?()
            }
        }
    }

    override func render(_ state: ResetPasswordViewModel.State) {
        if rootView.tokenFieldView.textField.text != state.token {
            rootView.tokenFieldView.textField.text = state.token
        }
        rootView.tokenFieldView.setValidationState(
            state.tokenValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )
        rootView.passwordFieldView.setValidationState(
            state.passwordValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )
        rootView.confirmPasswordFieldView.setValidationState(
            state.confirmPasswordValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )

        rootView.resetButton.isEnabled = state.isSubmitEnabled
        rootView.resetButton.alpha = state.isSubmitEnabled ? 1 : 0.6

        var resetButtonConfiguration = rootView.resetButton.configuration
        resetButtonConfiguration?.showsActivityIndicator = state.isLoading
        rootView.resetButton.configuration = resetButtonConfiguration

        let isInputEnabled = !state.isLoading
        rootView.tokenFieldView.textField.isEnabled = isInputEnabled
        rootView.passwordFieldView.textField.isEnabled = isInputEnabled
        rootView.confirmPasswordFieldView.textField.isEnabled = isInputEnabled

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            showAlert(title: "재설정 실패", message: errorMessage)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }

        if let successMessage = state.successMessage,
           successMessage != lastPresentedSuccessMessage {
            lastPresentedSuccessMessage = successMessage
            let alert = UIAlertController(title: nil, message: successMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
                self?.viewModel.send(.didAcknowledgeSuccess)
            })
            present(alert, animated: true)
        } else if state.successMessage == nil {
            lastPresentedSuccessMessage = nil
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    @objc private func tokenDidChange() {
        viewModel.send(.tokenChanged(rootView.tokenFieldView.textField.text ?? ""))
    }

    @objc private func passwordDidChange() {
        viewModel.send(.passwordChanged(rootView.passwordFieldView.textField.text ?? ""))
    }

    @objc private func confirmPasswordDidChange() {
        viewModel.send(.confirmPasswordChanged(rootView.confirmPasswordFieldView.textField.text ?? ""))
    }

    @objc private func didTapReset() {
        view.endEditing(true)
        viewModel.send(.submitTapped)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
