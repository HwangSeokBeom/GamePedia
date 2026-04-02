import UIKit

final class SocialActivityBannerPresenter {
    private struct QueuedBanner {
        let payload: SocialActivityBannerPayload
        let tapHandler: () -> Void
    }

    private weak var window: UIWindow?
    private var queue: [QueuedBanner] = []
    private var currentBannerView: SocialActivityBannerView?
    private var dismissWorkItem: DispatchWorkItem?

    init(window: UIWindow) {
        self.window = window
    }

    func enqueue(payload: SocialActivityBannerPayload, tapHandler: @escaping () -> Void) {
        guard SocialActivityDeduplicator.shared.shouldProcess("banner:\(payload.id)") else {
            return
        }

        queue.append(QueuedBanner(payload: payload, tapHandler: tapHandler))
        presentNextIfNeeded()
    }

    private func presentNextIfNeeded() {
        guard currentBannerView == nil, !queue.isEmpty, let window else { return }

        let queuedBanner = queue.removeFirst()
        let bannerView = SocialActivityBannerView()
        bannerView.configure(with: queuedBanner.payload)
        bannerView.alpha = 0
        bannerView.transform = CGAffineTransform(translationX: 0, y: -12)
        bannerView.addAction(
            UIAction { [weak self] _ in
                queuedBanner.tapHandler()
                self?.dismissCurrentBanner(animated: true)
            },
            for: .touchUpInside
        )

        window.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 10),
            bannerView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            bannerView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16)
        ])

        currentBannerView = bannerView

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            bannerView.alpha = 1
            bannerView.transform = .identity
        }

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.dismissCurrentBanner(animated: true)
        }
        self.dismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: dismissWorkItem)
    }

    private func dismissCurrentBanner(animated: Bool) {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let currentBannerView else {
            presentNextIfNeeded()
            return
        }

        let cleanup = { [weak self] in
            currentBannerView.removeFromSuperview()
            self?.currentBannerView = nil
            self?.presentNextIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
                currentBannerView.alpha = 0
                currentBannerView.transform = CGAffineTransform(translationX: 0, y: -10)
            } completion: { _ in
                cleanup()
            }
        } else {
            cleanup()
        }
    }
}
