import UIKit

final class SkeletonPlaceholderView: UIView {

    private enum Metrics {
        static let minimumOpacity: Float = 0.58
        static let animationDuration: CFTimeInterval = 0.9
    }

    init(cornerRadius: CGFloat = 12) {
        super.init(frame: .zero)
        backgroundColor = .gpSurfaceElevated
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            layer.removeAnimation(forKey: "skeleton.opacity")
        } else {
            startAnimating()
        }
    }

    private func startAnimating() {
        guard layer.animation(forKey: "skeleton.opacity") == nil else { return }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = Metrics.minimumOpacity
        animation.duration = Metrics.animationDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "skeleton.opacity")
    }
}
