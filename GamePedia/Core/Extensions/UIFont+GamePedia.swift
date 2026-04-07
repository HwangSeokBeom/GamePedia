import UIKit

extension UIFont {
    static func gpSerif(ofSize size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = baseFont.fontDescriptor.withDesign(.serif) ?? baseFont.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}
