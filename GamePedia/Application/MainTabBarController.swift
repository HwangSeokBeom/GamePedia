import UIKit

final class MainTabBarController: UITabBarController {

    private let tabNavigationControllers: [UINavigationController]
    private let buildInfoBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = .systemOrange.withAlphaComponent(0.92)
        label.layer.cornerRadius = 11
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    var onTabSelectionRequested: ((Int) -> Bool)?
    var onDebugEnvironmentMenuRequested: (() -> Void)?

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
        configureBuildInfoBadgeIfNeeded()
        configureDebugMenuGestureIfNeeded()
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

    private func configureBuildInfoBadgeIfNeeded() {
        guard AppConfig.shouldShowBuildIndicator else { return }
        guard buildInfoBadgeLabel.superview == nil else { return }

        buildInfoBadgeLabel.text = "  \(AppConfig.buildBadgeText)  "
        buildInfoBadgeLabel.backgroundColor = buildInfoBadgeBackgroundColor()

        view.addSubview(buildInfoBadgeLabel)

        NSLayoutConstraint.activate([
            buildInfoBadgeLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            buildInfoBadgeLabel.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -8),
            buildInfoBadgeLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
        ])
    }

    private func buildInfoBadgeBackgroundColor() -> UIColor {
        switch AppConfig.apiEnvironment {
        case .dev:
            return .systemRed.withAlphaComponent(0.92)
        case .staging:
            return .systemOrange.withAlphaComponent(0.92)
        case .production:
            return .systemBlue.withAlphaComponent(0.92)
        }
    }

    private func configureDebugMenuGestureIfNeeded() {
#if DEBUG
        let longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleTabBarLongPress(_:))
        )
        tabBar.addGestureRecognizer(longPressGestureRecognizer)
#endif
    }

    @objc
    private func handleTabBarLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
#if DEBUG
        guard gestureRecognizer.state == .began else { return }
        onDebugEnvironmentMenuRequested?()
#endif
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
