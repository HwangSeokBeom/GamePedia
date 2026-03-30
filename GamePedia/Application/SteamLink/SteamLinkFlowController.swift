import AuthenticationServices
import UIKit

protocol SteamLinkFlowControlling: AnyObject {
    func start(url: URL, presenter: UIViewController?)
    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool
}

final class SteamLinkFlowController: NSObject, SteamLinkFlowControlling {
    private var authenticationSession: ASWebAuthenticationSession?
    private weak var presentationAnchor: ASPresentationAnchor?
    private var lastHandledCallbackSignature: String?

    func start(url: URL, presenter: UIViewController?) {
        cancelActiveSession()
        lastHandledCallbackSignature = nil
        presentationAnchor = presenter?.view.window

        print("[SteamLink] flowStarted url=\(url.absoluteString)")

        let authenticationSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: SteamLinkCallbackParser.callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self else { return }

            if let callbackURL {
                _ = self.handleIncomingURL(callbackURL)
                return
            }

            if let authenticationError = error as? ASWebAuthenticationSessionError,
               authenticationError.code == .canceledLogin {
                print("[SteamLink] flowCancelled")
                self.publish(
                    SteamLinkCallbackResult(
                        status: .cancelled,
                        code: "CANCELLED",
                        message: nil,
                        linked: false
                    )
                )
                return
            }

            print("[SteamLink] flowFailed error=\(error?.localizedDescription ?? "unknown")")
            self.publish(
                SteamLinkCallbackResult(
                    status: .failed,
                    code: "AUTHENTICATION_SESSION_FAILED",
                    message: "Steam 연동을 완료하지 못했어요. 잠시 후 다시 시도해주세요.",
                    linked: false
                )
            )
        }
        authenticationSession.presentationContextProvider = self
        authenticationSession.prefersEphemeralWebBrowserSession = false

        guard authenticationSession.start() else {
            print("[SteamLink] flowStartFailed")
            publish(
                SteamLinkCallbackResult(
                    status: .failed,
                    code: "AUTHENTICATION_SESSION_START_FAILED",
                    message: "Steam 연동 창을 열지 못했어요. 잠시 후 다시 시도해주세요.",
                    linked: false
                )
            )
            return
        }

        self.authenticationSession = authenticationSession
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let result = SteamLinkCallbackParser.parse(url) else { return false }

        let callbackSignature = url.absoluteString
        guard callbackSignature != lastHandledCallbackSignature else {
            print("[SteamLink] callbackIgnored reason=duplicate")
            return true
        }

        print("[SteamLink] callbackReceived url=\(callbackSignature)")
        print("[SteamLink] callbackParsed status=\(result.status.logValue) linked=\(result.linked.map(String.init) ?? "nil")")

        lastHandledCallbackSignature = callbackSignature
        publish(result)
        return true
    }

    private func publish(_ result: SteamLinkCallbackResult) {
        authenticationSession = nil
        presentationAnchor = nil

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .steamLinkDidComplete,
                object: nil,
                userInfo: [SteamLinkChangeUserInfoKey.result: result]
            )
        }
    }

    private func cancelActiveSession() {
        authenticationSession?.cancel()
        authenticationSession = nil
        presentationAnchor = nil
    }
}

extension SteamLinkFlowController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let presentationAnchor {
            return presentationAnchor
        }

        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
           let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
            return keyWindow
        }

        return ASPresentationAnchor()
    }
}
