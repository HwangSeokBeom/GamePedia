import UIKit

#if DEBUG
enum EnvironmentDebugMenuPresenter {
    static func present(
        from presenter: UIViewController,
        currentEnvironment: APIEnvironment,
        selectedOverride: APIEnvironment?,
        onSelectEnvironment: @escaping (APIEnvironment?) -> Void
    ) {
        let alertController = UIAlertController(
            title: "서버 환경 전환",
            message: """
            현재 환경: \(currentEnvironment.rawValue)
            API: \(currentEnvironment.apiBaseURL.absoluteString)
            Translation: \(currentEnvironment.translationBaseURL.absoluteString)

            변경 후 앱을 다시 실행하면 반영됩니다.
            """,
            preferredStyle: .actionSheet
        )

        APIEnvironment.allCases.forEach { environment in
            let titleSuffix = selectedOverride == environment ? " ✓" : ""
            alertController.addAction(
                UIAlertAction(title: environment.rawValue + titleSuffix, style: .default) { _ in
                    onSelectEnvironment(environment)
                }
            )
        }

        alertController.addAction(
            UIAlertAction(title: "빌드 기본값 사용", style: .default) { _ in
                onSelectEnvironment(nil)
            }
        )
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
