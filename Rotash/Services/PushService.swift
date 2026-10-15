import FirebaseMessaging
import UIKit
import UserNotifications

/// 押し出し通知（「◯◯が撮った」）。
///
/// 朝の「今日は MINA」と夜の1通は、端末の中で予約する通知（NotificationScheduler）なので、サーバーが要らない。
/// 一方「今日の1枚が撮られた」は、撮った人の端末で起きたことなので、ほかの人の端末へはサーバーから送るしかない。
///
///   1. この端末の宛先（FCM トークン）を Firestore の `devices/{uid}` に置く（本人だけが書ける）
///   2. 誰かが今日の1枚を撮ると、その人の端末が送り役（Google Apps Script、`tools/push-relay.gs`）に知らせ（`PushRelay`）、
///      送り役が撮った人以外のメンバーの宛先へ「◯◯が撮った」を送る
///
/// 撮った本人には送らない。1つの枠につき1回だけ。
/// 送り役（Apps Script と APNs の鍵）を用意するまでは、宛先を置くだけで何も届かない（docs/PUSH_RELAY_SETUP.md）。
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
