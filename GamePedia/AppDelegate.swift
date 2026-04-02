//
//  AppDelegate.swift
//  GamePedia
//
//  Created by Hwangseokbeom on 3/21/26.
//

import UIKit
import GoogleSignIn
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppConfig.logRuntimeConfiguration()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }

        for connectedScene in UIApplication.shared.connectedScenes {
            guard let sceneDelegate = connectedScene.delegate as? SceneDelegate else { continue }
            if sceneDelegate.handleIncomingURL(url) {
                return true
            }
        }

        return false
    }


}

extension AppDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if let payload = SocialActivityPushPayload.parse(userInfo: userInfo),
           SocialActivityDeduplicator.shared.shouldProcess("push:\(payload.stableIdentity)", timeToLive: 60 * 5) {
            SocialActivityEventDispatcher.shared.send(.showBanner(payload.bannerPayload))
            completionHandler([])
            return
        }

        completionHandler([.badge, .sound, .banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let payload = SocialActivityPushPayload.parse(userInfo: userInfo) {
            SocialActivityEventDispatcher.shared.send(.route(payload.route))
        }
        completionHandler()
    }
}
