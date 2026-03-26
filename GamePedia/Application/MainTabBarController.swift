import UIKit

final class MainTabBarController: UITabBarController {

    private let customTabBarView = CustomTabBarView()
    private let tabNavigationControllers: [UINavigationController]

    // MARK: Init

    init(tabNavigationControllers: [UINavigationController]) {
        self.tabNavigationControllers = tabNavigationControllers
        super.init(nibName: nil, bundle: nil)
        viewControllers = tabNavigationControllers
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(tabNavigationControllers:)") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBarController()
        setupCustomTabBarView()
        bindCustomTabBarView()
        updateSelectedTab(index: selectedIndex)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutHiddenSystemTabBar()
    }

    private func setupTabBarController() {
        tabBar.isHidden = true
        tabBar.alpha = 0
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.backgroundColor = .clear
    }

    private func setupCustomTabBarView() {
        view.addSubview(customTabBarView)
        customTabBarView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            customTabBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            customTabBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            customTabBarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            customTabBarView.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    private func bindCustomTabBarView() {
        customTabBarView.onTabSelected = { [weak self] index in
            self?.selectedIndex = index
            self?.updateSelectedTab(index: index)
        }
    }

    private func updateSelectedTab(index: Int) {
        customTabBarView.updateSelectedIndex(index)
    }

    private func layoutHiddenSystemTabBar() {
        var frame = tabBar.frame
        frame.size.height = 0
        frame.origin.y = view.bounds.height + 100
        tabBar.frame = frame
    }

}
