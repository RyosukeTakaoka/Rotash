import FirebaseMessaging
import UIKit

/// 押し出し通知（「◯◯が撮った」）のために、APNs のデバイストークンを Firebase に渡すだけの係。
/// SwiftUI のアプリには AppDelegate が無いので、`RotashApp` から `@UIApplicationDelegateAdaptor` でつなぐ。
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        PushService.shared.start()
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 押し出し通知が使えないだけ。朝の通知・夜の1通（端末の中で作る通知）はそのまま届く。
    }
}
