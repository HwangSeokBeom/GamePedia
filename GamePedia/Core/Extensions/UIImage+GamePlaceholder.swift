import UIKit

extension UIImage {
    static let gpGameCoverPlaceholder: UIImage? = makeGameCoverPlaceholder()

    private static func makeGameCoverPlaceholder() -> UIImage? {
        let size = CGSize(width: 240, height: 320)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let backgroundPath = UIBezierPath(roundedRect: bounds, cornerRadius: 28)
            UIColor.gpSurface.setFill()
            backgroundPath.fill()

            let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 72, weight: .medium)
            let symbolImage = UIImage(
                systemName: "gamecontroller.fill",
                withConfiguration: symbolConfiguration
            )?.withTintColor(
                UIColor.gpTextSecondary.withAlphaComponent(0.78),
                renderingMode: .alwaysOriginal
            )

            let symbolSize = CGSize(width: 72, height: 72)
            let symbolOrigin = CGPoint(
                x: (size.width - symbolSize.width) / 2.0,
                y: (size.height - symbolSize.height) / 2.0
            )

            symbolImage?.draw(in: CGRect(origin: symbolOrigin, size: symbolSize))

            context.cgContext.setStrokeColor(UIColor.gpBorder.withAlphaComponent(0.45).cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.stroke(backgroundPath.bounds.insetBy(dx: 0.5, dy: 0.5))
        }
    }
}
