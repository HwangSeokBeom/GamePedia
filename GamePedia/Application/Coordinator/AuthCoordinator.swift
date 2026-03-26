import UIKit

final class AuthCoordinator {

    let navigationController: UINavigationController

    var onAuthenticated: (() -> Void)?

    private let loginUseCase: LoginUseCase
    private let signUpUseCase: SignUpUseCase

    init(
        loginUseCase: LoginUseCase,
        signUpUseCase: SignUpUseCase
    ) {
        self.loginUseCase = loginUseCase
        self.signUpUseCase = signUpUseCase
        navigationController = UINavigationController()
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)
    }

    func start() {
        showLogin()
    }

    private func showLogin() {
        let loginViewModel = LoginViewModel(loginUseCase: loginUseCase)
        let loginViewController = LoginViewController(viewModel: loginViewModel)
        loginViewController.navigationItem.backButtonDisplayMode = .minimal
        loginViewController.onLoginRequested = { [weak self] in
            self?.onAuthenticated?()
        }
        loginViewController.onSignUpRequested = { [weak self] in
            self?.showSignUp()
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
}
