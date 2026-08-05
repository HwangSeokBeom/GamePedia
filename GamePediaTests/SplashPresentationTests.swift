import XCTest
import UIKit
@testable import GamePedia

@MainActor
final class SplashPresentationTests: XCTestCase {

    func testLaunchStoryboardRendersTheLogoAtAReadableSize() throws {
        let storyboard = UIStoryboard(name: "LaunchScreen", bundle: .main)
        let viewController = try XCTUnwrap(storyboard.instantiateInitialViewController())
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        let imageView = try XCTUnwrap(viewController.view.firstDescendant(of: UIImageView.self))

        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(imageView.contentMode, .scaleAspectFit)
        XCTAssertGreaterThanOrEqual(imageView.bounds.width, 64)
        XCTAssertGreaterThanOrEqual(imageView.bounds.height, 47)
        XCTAssertEqual(imageView.center.x, viewController.view.bounds.midX, accuracy: 0.5)
        XCTAssertEqual(imageView.center.y, viewController.view.bounds.midY, accuracy: 0.5)
    }

    func testInAppSplashKeepsTheLogoReadableAfterLaunchScreenHandoff() throws {
        let viewController = SplashViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        let imageView = try XCTUnwrap(viewController.view.firstDescendant(of: UIImageView.self))

        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(imageView.contentMode, .scaleAspectFit)
        XCTAssertGreaterThanOrEqual(imageView.bounds.width, 64)
        XCTAssertGreaterThanOrEqual(imageView.bounds.height, 47)
    }
}

private extension UIView {
    func firstDescendant<View: UIView>(of type: View.Type) -> View? {
        if let match = self as? View {
            return match
        }

        return subviews.lazy.compactMap { $0.firstDescendant(of: type) }.first
    }
}
