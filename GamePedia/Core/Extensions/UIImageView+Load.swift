import UIKit
import Kingfisher

// MARK: - UIImageView + Kingfisher helpers

extension UIImageView {
    func loadImage(url: URL?, placeholder: UIImage? = nil) {
        kf.indicatorType = .activity
        kf.setImage(
            with: url,
            placeholder: placeholder,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        )
    }

    func cancelLoad() {
        kf.cancelDownloadTask()
    }
}
