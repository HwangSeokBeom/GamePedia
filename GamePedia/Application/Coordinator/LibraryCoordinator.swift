import UIKit

// MARK: - LibraryCoordinator

final class LibraryCoordinator {

    // MARK: Properties

    let navigationController: UINavigationController

    // MARK: Init

    init() {
        navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "라이브러리",
            image: UIImage(systemName: "books.vertical"),
            selectedImage: UIImage(systemName: "books.vertical.fill")
        )
        NavigationBarStyler.configureGlobalAppearance(on: navigationController.navigationBar)
    }

    // MARK: Start

    func start() {
        let libraryVC = LibraryViewController()
        navigationController.setViewControllers([libraryVC], animated: false)
    }
}
