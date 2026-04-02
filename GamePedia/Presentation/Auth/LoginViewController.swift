import AuthenticationServices
import GoogleSignIn
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
        rootView.appleButton.addTarget(self, action: #selector(didTapAppleLogin), for: .touchUpInside)
        rootView.googleButton.addTarget(self, action: #selector(didTapGoogleLogin), for: .touchUpInside)
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
        rootView.appleButton.isEnabled = !state.isLoading
        rootView.googleButton.isEnabled = !state.isLoading
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
    private func didTapAppleLogin() {
        view.endEditing(true)
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    @objc
    private func didTapGoogleLogin() {
        view.endEditing(true)
        guard let clientID = AppConfig.googleClientID,
              let reverseClientID = AppConfig.googleReverseClientID,
              hasURLScheme(reverseClientID) else {
            viewModel.send(.googleLoginFailed(.googleLoginNotConfigured))
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] signInResult, error in
            guard let self else { return }

            if let error = error as NSError? {
                if error.code == GIDSignInError.canceled.rawValue {
                    self.viewModel.send(.googleLoginFailed(.socialLoginCancelled))
                    return
                }

                self.viewModel.send(.googleLoginFailed(.unknown(message: error.localizedDescription)))
                return
            }

            let user = signInResult?.user
            let idToken = user?.idToken?.tokenString
            let accessToken = user?.accessToken.tokenString
            let userID = user?.userID

            print("[GoogleLogin] idToken exists:", idToken != nil)
            print("[GoogleLogin] accessToken length:", accessToken?.count ?? 0)
            print("[GoogleLogin] userID exists:", userID != nil)

            guard let idToken else {
                self.viewModel.send(.googleLoginFailed(.invalidResponse))
                return
            }

            self.viewModel.send(
                .googleLoginSucceeded(
                    GoogleLoginCredential(
                        idToken: idToken,
                        accessToken: accessToken,
                        userID: userID,
                        deviceName: UIDevice.current.name
                    )
                )
            )
        }
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

    private func hasURLScheme(_ scheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        return urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
            .contains(scheme)
    }
}

extension LoginViewController: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            viewModel.send(.appleLoginFailed(.invalidResponse))
            return
        }

        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            viewModel.send(.appleLoginFailed(.invalidResponse))
            return
        }

        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let payload = AppleLoginCredential(
            userIdentifier: credential.user,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            email: credential.email,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName
        )

        viewModel.send(.appleLoginSucceeded(payload))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            viewModel.send(.appleLoginFailed(.socialLoginCancelled))
            return
        }

        viewModel.send(.appleLoginFailed(.unknown(message: error.localizedDescription)))
    }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}
