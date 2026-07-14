import FirebaseCore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()

    private let registrar: FCMTokenRegistrar
    private var hasStarted = false
    private var authObserver: NSObjectProtocol?

    private override init() {
        self.registrar = FCMTokenRegistrar()
        super.init()
    }

    func start(application: UIApplication) {
        guard !hasStarted else { return }
        hasStarted = true

        configureFirebaseIfNeeded()
        Messaging.messaging().delegate = self
        observeAuthChanges()
        requestAuthorizationAndRegister(application: application)
        fetchFCMToken(source: "appStart")
    }

    func applicationDidRegisterForRemoteNotifications(deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("[FCM] APNs device token registered")
        fetchFCMToken(source: "apnsRegistered")
    }

    func applicationDidFailToRegisterForRemoteNotifications(error: Error) {
        print("[FCM] APNs device token registration failed error=\(error.localizedDescription)")
    }

    func fetchFCMToken(source: String) {
        guard FirebaseApp.app() != nil else {
            print("[FCM] token fetch skipped reason=firebaseUnavailable source=\(source)")
            return
        }

        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("[FCM] token fetch failed source=\(source) error=\(error.localizedDescription)")
                return
            }

            guard let token, token.isEmpty == false else {
                print("[FCM] token fetch skipped reason=empty source=\(source)")
                return
            }

            self?.logTokenSummary(token, source: source)
            Task {
                await self?.registrar.register(token: token, source: source)
            }
        }
    }

    func registerPendingTokenIfPossible(source: String) {
        Task {
            await registrar.registerPendingTokenIfPossible(source: source)
        }
    }

    func deleteRegisteredTokenOnLogout(accessToken: String?) {
        Task {
            await registrar.deleteRegisteredTokenOnLogout(accessToken: accessToken)
        }
    }

    private func configureFirebaseIfNeeded() {
        if FirebaseApp.app() != nil {
            print("[FCM] Firebase configured")
            return
        }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("[FCM] Firebase configure skipped reason=missingGoogleServiceInfoPlist")
            return
        }

        FirebaseApp.configure()
        print("[FCM] Firebase configured")
    }

    private func requestAuthorizationAndRegister(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("[FCM] notification permission error=\(error.localizedDescription)")
            }
            print("[FCM] notification permission granted=\(granted)")

            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    private func observeAuthChanges() {
        authObserver = NotificationCenter.default.addObserver(
            forName: .authSessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let isAuthenticated = notification.userInfo?[AuthSessionChangeUserInfoKey.isAuthenticated] as? Bool ?? false
            guard isAuthenticated else { return }
            self?.registerPendingTokenIfPossible(source: "authSessionChanged")
            self?.fetchFCMToken(source: "authSessionChanged")
        }
    }

    private func logTokenSummary(_ token: String, source: String) {
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        print(
            "[FCM] didReceiveRegistrationToken exists=true " +
            "prefix=\(prefix) suffix=\(suffix) length=\(token.count) source=\(source)"
        )
    }
}

extension PushNotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, fcmToken.isEmpty == false else {
            print("[FCM] didReceiveRegistrationToken exists=false")
            return
        }

        logTokenSummary(fcmToken, source: "messagingDelegate")
        Task {
            await registrar.register(token: fcmToken, source: "messagingDelegate")
        }
    }
}
