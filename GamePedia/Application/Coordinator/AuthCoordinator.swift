import UIKit

final class AuthCoordinator {

    let navigationController: UINavigationController

    var onAuthenticated: (() -> Void)?

    private let loginUseCase: LoginUseCase
    private let appleLoginUseCase: AppleLoginUseCase
    private let googleLoginUseCase: GoogleLoginUseCase
    private let signUpUseCase: SignUpUseCase
    private let forgotPasswordUseCase: ForgotPasswordUseCase
    private let resetPasswordUseCase: ResetPasswordUseCase

    init(
        loginUseCase: LoginUseCase,
        appleLoginUseCase: AppleLoginUseCase,
        googleLoginUseCase: GoogleLoginUseCase,
        signUpUseCase: SignUpUseCase,
        forgotPasswordUseCase: ForgotPasswordUseCase,
        resetPasswordUseCase: ResetPasswordUseCase
    ) {
        self.loginUseCase = loginUseCase
        self.appleLoginUseCase = appleLoginUseCase
        self.googleLoginUseCase = googleLoginUseCase
        self.signUpUseCase = signUpUseCase
        self.forgotPasswordUseCase = forgotPasswordUseCase
        self.resetPasswordUseCase = resetPasswordUseCase
        navigationController = UINavigationController()
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)
    }

    func start(resetPasswordToken: String? = nil) {
        showLogin()
        if resetPasswordToken != nil {
            showResetPassword(token: resetPasswordToken)
        }
    }

    private func showLogin() {
        let loginViewModel = LoginViewModel(
            loginUseCase: loginUseCase,
            appleLoginUseCase: appleLoginUseCase,
            googleLoginUseCase: googleLoginUseCase
        )
        let loginViewController = LoginViewController(viewModel: loginViewModel)
        loginViewController.navigationItem.backButtonDisplayMode = .minimal
        loginViewController.onLoginRequested = { [weak self] in
            self?.onAuthenticated?()
        }
        loginViewController.onSignUpRequested = { [weak self] in
            self?.showSignUp()
        }
        loginViewController.onForgotPasswordRequested = { [weak self] in
            self?.showForgotPassword()
        }
        navigationController.setViewControllers([loginViewController], animated: false)
    }

    private func showSignUp() {
        let signUpViewModel = SignUpViewModel(signUpUseCase: signUpUseCase)
        let signUpViewController = SignUpViewController(viewModel: signUpViewModel)
        signUpViewController.onBackRequested = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        signUpViewController.onLoginRequested = { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        signUpViewController.onSignUpRequested = { [weak self] in
            self?.onAuthenticated?()
        }
        navigationController.pushViewController(signUpViewController, animated: true)
    }

    private func showForgotPassword() {
        let forgotPasswordViewModel = ForgotPasswordViewModel(
            forgotPasswordUseCase: forgotPasswordUseCase
        )
        let forgotPasswordViewController = ForgotPasswordViewController(
            rootView: ForgotPasswordRootView(),
            viewModel: forgotPasswordViewModel
        )
        forgotPasswordViewController.onShowResetPassword = { [weak self] token in
            self?.showResetPassword(token: token)
        }
        forgotPasswordViewController.onCompleted = { [weak self] in
            self?.navigationController.popToRootViewController(animated: true)
        }
        navigationController.pushViewController(forgotPasswordViewController, animated: true)
    }

    func showResetPassword(token: String?) {
        let resetPasswordViewModel = ResetPasswordViewModel(
            token: token,
            resetPasswordUseCase: resetPasswordUseCase
        )
        let resetPasswordViewController = ResetPasswordViewController(
            rootView: ResetPasswordRootView(),
            viewModel: resetPasswordViewModel
        )
        resetPasswordViewController.onCompleted = { [weak self] in
            self?.navigationController.popToRootViewController(animated: true)
        }
        navigationController.pushViewController(resetPasswordViewController, animated: true)
    }
}
