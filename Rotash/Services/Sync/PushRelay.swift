import Foundation

/// 「◯◯が今日の1枚を撮りました」を、ほかのメンバーに送ってもらう。
///
/// 送る役は Google Apps Script のウェブアプリ（`tools/push-relay.gs`。無料）。
/// Firebase の Cloud Functions は従量課金でないと動かせないので使わない。
///
/// 今日の1枚を撮ってサーバーに上げたあと、ここから送り役に「撮った」と知らせるだけ。
/// 送り役が、本当にこの人が今日その枠を撮ったかを Firestore で確かめてから、ほかの人へ送る。
/// 同じ枠で知らせるのは1回だけ（撮り直しや、同期のたびには知らせない）。
/// 送り役の URL（`SyncConfig.pushRelayURL`）が空のあいだは、何もしない。
enum PushRelay {

    private static let sentKey = "rotash.pushRelay.sent"
    /// いま知らせている最中の枠。撮った直後は同期が続けて走るので、同じ知らせを2つ同時に出さないように。
    @MainActor private static var inFlight = Set<String>()

    /// 今日の枠を自分が撮っていて、まだ知らせていなければ知らせる。同期が終わったあとに呼ぶ。
    @MainActor
    static func notifyIfNeeded(for group: RotashGroup, now: Date = Date()) async {
        guard let url = URL(string: SyncConfig.pushRelayURL), !SyncConfig.pushRelayURL.isEmpty else { return }
        let week = group.currentWeek
        guard week.startDate == Calendar.startOfWeek(for: now) else { return }
        let today = Calendar.dayIndex(for: now, weekStart: week.startDate)
        // サーバーに写真が載ってから（photoURL が付いてから）でないと、送り役が確かめられない。
        guard let slot = week.slot(at: today), slot.isFilled, slot.photoURL != nil,
              slot.takenByMemberID == group.myMemberID
        else { return }

        let key = "\(group.inviteCode)|\(Int(week.startDate.timeIntervalSince1970))|\(today)"
        var sent = UserDefaults.standard.stringArray(forKey: sentKey) ?? []
        guard !sent.contains(key), !inFlight.contains(key) else { return }
        inFlight.insert(key)
        defer { inFlight.remove(key) }
        guard let idToken = await AuthService.shared.idToken() else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        let body: [String: Any] = ["idToken": idToken, "inviteCode": group.inviteCode, "dayIndex": today]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        // Apps Script は一度別の URL へ転送してから答えを返す（URLSession が自動でたどる）。
        guard let reply = try? await URLSession.shared.data(for: request),
              (reply.1 as? HTTPURLResponse)?.statusCode == 200,
              let answer = try? JSONSerialization.jsonObject(with: reply.0) as? [String: Any],
              answer["ok"] as? Bool == true
        else { return }   // 届かなければ、次の同期でもう一度

        sent.append(key)
        UserDefaults.standard.set(Array(sent.suffix(60)), forKey: sentKey)
    }
}
