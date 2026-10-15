import FirebaseMessaging
import UIKit
import UserNotifications

/// 押し出し通知（「◯◯が撮った」）。
///
/// 朝の「今日は MINA」と夜の1通は、端末の中で予約する通知（NotificationScheduler）なので、サーバーが要らない。
/// 一方「今日の1枚が撮られた」は、撮った人の端末で起きたことなので、ほかの人の端末へはサーバーから送るしかない。
///
///   1. この端末の宛先（FCM トークン）を Firestore の `devices/{uid}` に置く（本人だけが書ける）
///   2. 誰かが撮ってグループの状態が書き換わると、Cloud Functions（functions/index.js）が
///      新しく埋まった枠を見つけ、撮った人以外のメンバーの宛先へ「◯◯が撮った」を送る
///
/// 1日に届くのは、朝の1通とこの1通まで（`GROWTH_STRATEGY.md` F-3）。撮った本人には送らない。
/// サーバー側（Cloud Functions と APNs の鍵）を用意するまでは、宛先を置くだけで何も届かない。
@MainActor
final class PushService: NSObject, MessagingDelegate {

    static let shared = PushService()

    private var lastUploadedToken: String?

    func start() {
        Messaging.messaging().delegate = self
        // 通知の許可がすでにあれば、押し出し通知の登録もしておく（許可を聞くのはグループができてから）。
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// 通知の許可が取れたあとに呼ぶ。
    func registerIfAuthorized(_ granted: Bool) {
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in await self.upload(fcmToken) }
    }

    /// 宛先を Firestore に置く。匿名ログインできていないと置けない（置く場所が uid ごとなので）。
    private func upload(_ token: String) async {
        guard token != lastUploadedToken,
              let uid = await AuthService.shared.uid()
        else { return }
        let language = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        do {
            try await FirestoreClient.saveDevice(uid: uid, token: token, language: language)
            lastUploadedToken = token
        } catch {
            // 次に起動したとき（トークンがもう一度届いたとき）にまた置く。
        }
    }
}
