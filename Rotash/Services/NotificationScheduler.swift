import Foundation
import UserNotifications

/// 「今日は誰？」を毎朝ひとつだけ届ける。
///
/// 担当は週の開始時点で内部的に決まっているので、**その週の分をまとめて予約するだけ**で済む。
/// サーバーも APNs も要らない。
///
/// 送るのは2種類だけで、上限は 1日2通。
///
///   朝 8:00     「今日は MINA」          … 全員に。日次ループの起点
///   日曜 21:00  「今週の Rotash」        … 週に1度だけ。作品が決着する日
///
/// これ以外は送らない。特に、
///   ・「まだ撮っていません」の催促を繰り返す
///   ・「あと2枚で完成！」と進捗を煽る
///   ・「3日間開いていません」とアプリの都合を伝える
/// は入れない。通知が「友達について」ではなく「アプリについて」になった時点で、
/// Rotash は毎朝の楽しみではなく義務になる。
enum NotificationScheduler {

    private static let prefix = "rotash.day."
    private static let weekEndPrefix = "rotash.weekend."

    /// 朝の通知を出す時刻。
    ///
    /// 深夜0時ではなく朝8時に全員へ同時に出すことで、
    /// 「Rotash の1日は朝8時に始まる」という共有された時刻ができる。
    /// 撮影は非同期でよいが、朝の合図だけは揃えたい。
    private static let morningHour = 8
    private static let weekEndHour = 21

    // MARK: - 許可

    /// 通知の許可を求める。グループができてから呼ぶ（起動直後には何も通知するものが無い）。
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        default:
            return true
        }
    }

    // MARK: - 予約

    /// その週の通知を組み直す。担当が変わるたびに呼ぶ。
    ///
    /// 途中参加で未来の担当が入れ替わることがあるので、**必ず全部消してから入れ直す**。
    /// 差分で消そうとすると、消し忘れた古い名前がそのまま朝に届く。
    static func reschedule(for group: RotashGroup?, now: Date = Date()) {
        // 予約する内容はクロージャに入る前に作っておく
        // （グループの状態をクロージャへ持ち込まないため）。
        let next = group.map { requests(for: $0, now: now) } ?? []

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter {
                $0.hasPrefix(prefix) || $0.hasPrefix(weekEndPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            for request in next {
                center.add(request)
            }
        }
    }

    /// 予約する内容。副作用が無いので、そのまま確かめられる。
    static func requests(for group: RotashGroup, now: Date = Date()) -> [UNNotificationRequest] {
        let calendar = Calendar.rotash
        let week = group.currentWeek
        var result: [UNNotificationRequest] = []

        for slot in week.slots.sorted(by: { $0.dayIndex < $1.dayIndex }) {
            guard let name = group.member(forDay: slot.dayIndex, in: week)?.name,
                  let date = fireDate(dayIndex: slot.dayIndex,
                                      weekStart: week.startDate,
                                      hour: morningHour,
                                      calendar: calendar),
                  date > now
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "TODAY"
            content.body = "今日は \(name.uppercased())"
            content.sound = .default

            result.append(request(id: "\(prefix)\(stamp(week.startDate))-\(slot.dayIndex)",
                                  date: date,
                                  content: content,
                                  calendar: calendar))
        }

        // 日曜の夜。7枚そろっていても、撮れなかった日があっても、その週は決着している。
        // 「完成した瞬間」を全員に届けるにはプッシュが要るので、そこは後で。
        if let date = fireDate(dayIndex: 6,
                               weekStart: week.startDate,
                               hour: weekEndHour,
                               calendar: calendar),
           date > now {
            let content = UNMutableNotificationContent()
            content.title = "THIS WEEK"
            content.body = "今週の Rotash"
            content.sound = .default

            result.append(request(id: "\(weekEndPrefix)\(stamp(week.startDate))",
                                  date: date,
                                  content: content,
                                  calendar: calendar))
        }

        return result
    }

    // MARK: -

    private static func request(id: String,
                                date: Date,
                                content: UNNotificationContent,
                                calendar: Calendar) -> UNNotificationRequest {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private static func fireDate(dayIndex: Int,
                                 weekStart: Date,
                                 hour: Int,
                                 calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) else { return nil }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }

    private static func stamp(_ date: Date) -> String {
        RotashDateFormat.fileStamp.string(from: date)
    }
}
