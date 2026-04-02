import UIKit

final class ForgotPasswordViewController: BaseViewController<ForgotPasswordRootView, ForgotPasswordViewModel.State> {

    private let viewModel: ForgotPasswordViewModel
    private var lastPresentedErrorMessage: String?
    private var lastPresentedSuccessMessage: String?

    var onShowResetPassword: ((String?) -> Void)?
    var onCompleted: (() -> Void)?

    init(
        rootView: ForgotPasswordRootView = ForgotPasswordRootView(),
        viewModel: ForgotPasswordViewModel
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
            navigationItem.title = L10n.tr("Localizable", "auth.forgotPassword.title")
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.backButtonDisplayMode = .minimal
        }
    }

    private func setupActions() {
        rootView.emailFieldView.textField.addTarget(self, action: #selector(emailDidChange), for: .editingChanged)
        rootView.sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        rootView.resetPasswordButton.addTarget(self, action: #selector(didTapManualReset), for: .touchUpInside)
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
            case .showResetPassword(let token):
                self?.onShowResetPassword?(token)
            case .showLogin:
                self?.onCompleted?()
            }
        }
    }

    override func render(_ state: ForgotPasswordViewModel.State) {
        rootView.emailFieldView.setValidationState(
            state.emailValidationMessage.map(AuthInputFieldView.ValidationState.error) ?? .hidden
        )

        rootView.sendButton.isEnabled = state.isSubmitEnabled
        rootView.sendButton.alpha = state.isSubmitEnabled ? 1 : 0.6

        var sendButtonConfiguration = rootView.sendButton.configuration
        sendButtonConfiguration?.showsActivityIndicator = state.isLoading
        rootView.sendButton.configuration = sendButtonConfiguration

        let isInputEnabled = !state.isLoading
        rootView.emailFieldView.textField.isEnabled = isInputEnabled
        rootView.resetPasswordButton.isEnabled = isInputEnabled

        if let errorMessage = state.errorMessage,
           errorMessage != lastPresentedErrorMessage {
            lastPresentedErrorMessage = errorMessage
            showAlert(title: L10n.Common.Error.title, message: errorMessage)
        } else if state.errorMessage == nil {
            lastPresentedErrorMessage = nil
        }

        if let successMessage = state.successMessage,
           successMessage != lastPresentedSuccessMessage {
            lastPresentedSuccessMessage = successMessage
            let alert = UIAlertController(title: nil, message: successMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("Localizable", "common.button.ok"), style: .default) { [weak self] _ in
                self?.viewModel.send(.didAcknowledgeSuccess)
            })
            present(alert, animated: true)
        } else if state.successMessage == nil {
            lastPresentedSuccessMessage = nil
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("Localizable", "common.button.ok"), style: .default))
        present(alert, animated: true)
    }

    @objc private func emailDidChange() {
        viewModel.send(.emailChanged(rootView.emailFieldView.textField.text ?? ""))
    }

    @objc private func didTapSend() {
        view.endEditing(true)
        viewModel.send(.submitTapped)
    }

    @objc private func didTapManualReset() {
        view.endEditing(true)
        viewModel.send(.didTapManualReset)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
