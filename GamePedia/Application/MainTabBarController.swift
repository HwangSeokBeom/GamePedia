import UIKit

final class MainTabBarController: UITabBarController {

    private let tabNavigationControllers: [UINavigationController]
    var onTabSelectionRequested: ((Int) -> Bool)?

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
    }

    private func setupTabBarController() {
        view.backgroundColor = .gpBackground
        delegate = self
        tabBar.isHidden = false
        tabBar.alpha = 1
        tabBar.isTranslucent = true
        tabBar.backgroundImage = nil
        tabBar.shadowImage = nil
        applyTabBarAppearance()
    }

    private func applyTabBarAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundEffect = makeTabBarBlurEffect()
        tabBarAppearance.backgroundColor = .gpTabBarBackground
        tabBarAppearance.shadowColor = .gpTabBarSeparator

        let itemAppearance = UITabBarItemAppearance(style: .stacked)
        itemAppearance.selected.iconColor = .gpAccent
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.gpAccent]
        itemAppearance.normal.iconColor = .gpTextSecondary
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gpTextSecondary]
        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        tabBarAppearance.inlineLayoutAppearance = itemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = itemAppearance
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.tintColor = .gpAccent
        tabBar.unselectedItemTintColor = .gpTextSecondary
    }

    func selectTab(index: Int) {
        guard tabNavigationControllers.indices.contains(index) else { return }
        selectedIndex = index
    }

    private func makeTabBarBlurEffect() -> UIBlurEffect {
        UIBlurEffect(style: .systemChromeMaterialDark)
    }
}

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let viewControllers,
              let index = viewControllers.firstIndex(of: viewController) else {
            return true
        }

        return onTabSelectionRequested?(index) ?? true
    }
}
