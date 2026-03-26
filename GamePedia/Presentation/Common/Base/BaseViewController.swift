import UIKit

// MARK: - BaseViewController
// Subclasses override render(_:) to update UI from state.
// No Combine/RxSwift — ViewModel calls onStateChanged callback.

class BaseViewController<RootView: UIView, State>: UIViewController {

    // MARK: Properties
    let rootView: RootView

    // MARK: Init
    init(rootView: RootView) {
        self.rootView = rootView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(rootView:)") }

    // MARK: Lifecycle
    override func loadView() {
        view = rootView
    }

    // MARK: State Rendering — override in subclass
    func render(_ state: State) {
        // Subclasses forward to rootView or update nav items
    }
}
