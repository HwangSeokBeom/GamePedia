import UIKit
import Kingfisher
import ObjectiveC

// MARK: - UIImageView + Kingfisher helpers

extension UIImageView {
    func loadImage(
        url: URL?,
        fallbackURLs: [URL] = [],
        placeholder: UIImage? = nil,
        logContext: String? = nil
    ) {
        cancelLoad()
        kf.indicatorType = .activity

        let orderedURLs = ([url] + fallbackURLs)
            .compactMap { $0 }
            .reduce(into: [URL]()) { partialResult, candidate in
                guard partialResult.contains(candidate) == false else { return }
                partialResult.append(candidate)
            }

        guard !orderedURLs.isEmpty else {
            image = placeholder
            logFallback(
                context: logContext,
                reason: "missing_url",
                failedURL: nil,
                nextURL: nil,
                placeholderApplied: placeholder != nil
            )
            return
        }

        let requestID = UUID().uuidString
        currentImageLoadRequestID = requestID
        setImage(
            orderedURLs: orderedURLs,
            index: 0,
            requestID: requestID,
            placeholder: placeholder,
            logContext: logContext
        )
    }

    func cancelLoad() {
        kf.cancelDownloadTask()
        kf.indicatorType = .none
        currentImageLoadRequestID = nil
    }

    private func setImage(
        orderedURLs: [URL],
        index: Int,
        requestID: String,
        placeholder: UIImage?,
        logContext: String?
    ) {
        guard index < orderedURLs.count else {
            image = placeholder
            logFallback(
                context: logContext,
                reason: "all_candidates_failed",
                failedURL: nil,
                nextURL: nil,
                placeholderApplied: placeholder != nil
            )
            return
        }

        let currentURL = orderedURLs[index]

        kf.setImage(
            with: currentURL,
            placeholder: placeholder,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage
            ]
        ) { [weak self] result in
            guard let self else { return }
            guard self.currentImageLoadRequestID == requestID else { return }

            switch result {
            case .success:
                self.kf.indicatorType = .none

            case .failure(let error):
                let nextIndex = index + 1
                let nextURL = nextIndex < orderedURLs.count ? orderedURLs[nextIndex] : nil

                self.logFallback(
                    context: logContext,
                    reason: Self.fallbackReason(from: error),
                    failedURL: currentURL,
                    nextURL: nextURL,
                    placeholderApplied: nextURL == nil && placeholder != nil
                )

                if nextIndex < orderedURLs.count {
                    self.setImage(
                        orderedURLs: orderedURLs,
                        index: nextIndex,
                        requestID: requestID,
                        placeholder: placeholder,
                        logContext: logContext
                    )
                    return
                }

                self.kf.indicatorType = .none
                self.image = placeholder
            }
        }
    }

    private func logFallback(
        context: String?,
        reason: String,
        failedURL: URL?,
        nextURL: URL?,
        placeholderApplied: Bool
    ) {
        guard let context else { return }

        print(
            "[GameImageLoader] " +
            "context=\(context) " +
            "fallbackReason=\(reason) " +
            "failedURL=\(failedURL?.absoluteString ?? "nil") " +
            "nextURL=\(nextURL?.absoluteString ?? "nil") " +
            "placeholderApplied=\(placeholderApplied)"
        )
    }

    private static func fallbackReason(from error: KingfisherError) -> String {
        if error.isNotCurrentTask {
            return "not_current_source_task"
        }

        if error.isTaskCancelled {
            return "task_cancelled"
        }

        switch error {
        case .responseError(let reason):
            return "response_\(String(describing: reason))"
        case .requestError(let reason):
            return "request_\(String(describing: reason))"
        case .cacheError(let reason):
            return "cache_\(String(describing: reason))"
        case .processorError(let reason):
            return "processor_\(String(describing: reason))"
        case .imageSettingError(let reason):
            return "image_setting_\(String(describing: reason))"
        @unknown default:
            return "unknown_kingfisher_error"
        }
    }

    private var currentImageLoadRequestID: String? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.imageLoadRequestID) as? String
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.imageLoadRequestID,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private enum AssociatedKeys {
    static var imageLoadRequestID: UInt8 = 0
}
