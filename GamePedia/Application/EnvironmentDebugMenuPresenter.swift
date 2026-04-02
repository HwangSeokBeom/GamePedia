import UIKit

#if DEBUG
enum EnvironmentDebugMenuPresenter {
    static func present(
        from presenter: UIViewController,
        currentEnvironment: APIEnvironment
    ) {
        let alertController = UIAlertController(
            title: "서버 환경 정보",
            message: """
            현재 환경: \(currentEnvironment.rawValue)
            API: \(currentEnvironment.apiBaseURL.absoluteString)

            환경은 빌드 설정과 스킴으로 결정됩니다.
            """,
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))

        if let popoverPresentationController = alertController.popoverPresentationController {
            popoverPresentationController.sourceView = presenter.view
            popoverPresentationController.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 24,
                width: 1,
                height: 1
            )
        }

        presenter.present(alertController, animated: true)
    }
}
#endif
