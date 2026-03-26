import UIKit
import SwiftUI

final class TranslationHostContainerViewController: UIViewController {

    private let onResult: ([TranslationResultItem]) -> Void
    private var currentRequest: TranslationBatchRequest?
    private var hostingController: UIHostingController<AnyView>?

    init(onResult: @escaping ([TranslationResultItem]) -> Void) {
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(onResult:)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        installHostingController()
        renderRootView()
    }

    func update(request: TranslationBatchRequest?) {
        guard currentRequest != request else { return }
        currentRequest = request
        guard isViewLoaded else { return }
        renderRootView()
    }

    private func installHostingController() {
        let hostingController = UIHostingController(rootView: AnyView(Color.clear))
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    private func renderRootView() {
        guard let hostingController else { return }

        if #available(iOS 26.0, *) {
            hostingController.rootView = AnyView(
                TranslationHostView(request: currentRequest, onResult: onResult)
            )
        } else {
            if currentRequest != nil {
                print("[TranslationHost] skipped reason=unsupported-os")
            }
            hostingController.rootView = AnyView(Color.clear)
        }
    }
}
