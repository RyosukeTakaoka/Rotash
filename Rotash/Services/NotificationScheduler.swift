import Foundation
import UserNotifications

/// 「今日は誰？」を毎朝ひとつだけ届ける。
///
/// 担当は週の開始時点で内部的に決まっているので、**その週の分をまとめて予約するだけ**で済む。
/// サーバーも APNs も要らない。
///
/// 送るのは3種類だけ（グループを掛け持ちしていても、同じ時刻のものは1通にまとめる）。
///
///   朝 8:00     「今日は MINA」          … 全員に。日次ループの起点
///   夜 21:00    「まだ撮れます」          … **その日の担当の本人にだけ**、まだ撮っていないときだけ
///   日曜 21:00  「今週の Rotash」        … 週に1度だけ。作品が決着する日
///
/// 夜の1通は、友達テストで「通知に気づかず撮り忘れた」という声があって足した（#21）。
/// 担当でない人には届かず、撮れば消える（撮ると予約を組み直すので）。1日1回きりで、重ねて催促はしない。
/// 日曜は夜の1通と「今週の Rotash」が同じ時刻になるので、まだ撮っていない担当の端末には夜の1通だけを出す
/// （その人にとって週はまだ決着していない）。
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
    private static let reminderPrefix = "rotash.remind."

    /// 朝の通知を出す時刻。
    ///
    /// 深夜0時ではなく朝8時に全員へ同時に出すことで、
    /// 「Rotash の1日は朝8時に始まる」という共有された時刻ができる。
    /// 撮影は非同期でよいが、朝の合図だけは揃えたい。
    private static let morningHour = 8
    private static let weekEndHour = 21
    /// 担当の本人への夜の1通。寝る前に思い出せて、撮れる時間がまだ3時間ある時刻。
    private static let reminderHour = 21

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
    /// 掛け持ちしているときは、同じ時刻の通知を1通にまとめる（グループの数だけ朝に届くと、うるさい上に
    /// iOS の予約できる上限（64件）にもすぐ届く）。本文に「グループ名: 担当」を1行ずつ並べる。
    static func reschedule(for groups: [RotashGroup], now: Date = Date()) {
        // 予約する内容はクロージャに入る前に作っておく
        // （グループの状態をクロージャへ持ち込まないため）。
        let next = groups.count > 1
            ? combinedRequests(for: groups, now: now)
            : groups.flatMap { requests(for: $0, now: now) }

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ours = pending.map(\.identifier).filter {
                $0.hasPrefix(prefix) || $0.hasPrefix(weekEndPrefix) || $0.hasPrefix(reminderPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            for request in next {
                center.add(request)
            }
        }
    }

    /// 掛け持ちしているときの予約。朝は日ごとに1通（各グループの今日の担当を1行ずつ）、日曜の夜も1通。
    static func combinedRequests(for groups: [RotashGroup], now: Date = Date()) -> [UNNotificationRequest] {
        let calendar = Calendar.rotash
        var mornings: [Date: [String]] = [:]
        var reminders: [Date: [String]] = [:]
        var weekEnds = Set<Date>()

        for group in groups {
            let week = group.currentWeek
            for slot in week.slots.sorted(by: { $0.dayIndex < $1.dayIndex }) {
                guard let name = group.member(forDay: slot.dayIndex, in: week)?.name else { continue }
                if let date = fireDate(dayIndex: slot.dayIndex, weekStart: week.startDate,
                                       hour: morningHour, calendar: calendar),
                   date > now {
                    mornings[date, default: []].append("\(group.name): \(name.uppercased())")
                }
                if let evening = reminderDate(for: slot, in: group, now: now, calendar: calendar) {
                    reminders[evening, default: []].append(group.name)
                }
            }
            if let date = fireDate(dayIndex: 6, weekStart: week.startDate, hour: weekEndHour, calendar: calendar),
               date > now {
                weekEnds.insert(date)
            }
        }

        var result: [UNNotificationRequest] = []
        for (date, lines) in mornings.sorted(by: { $0.key < $1.key }) {
            let content = UNMutableNotificationContent()
            content.title = "TODAY"
            content.body = lines.joined(separator: "\n")
            content.sound = .default
            result.append(request(id: "\(prefix)\(stamp(date))",
                                  date: date, content: content, calendar: calendar))
        }
        for (date, names) in reminders.sorted(by: { $0.key < $1.key }) {
            let content = reminderContent(groupNames: names)
            result.append(request(id: "\(reminderPrefix)\(stamp(date))",
                                  date: date, content: content, calendar: calendar))
        }
        // 夜の1通と同じ時刻になる日曜は、そちらだけにする（1つの端末に同じ時刻の2通を出さない）。
        for date in weekEnds.sorted() where reminders[date] == nil {
            let content = UNMutableNotificationContent()
            content.title = "THIS WEEK"
            content.body = String(localized: "今週の Rotash")
            content.sound = .default
            result.append(request(id: "\(weekEndPrefix)\(stamp(date))",
                                  date: date, content: content, calendar: calendar))
        }
        return result
    }

    /// 予約する内容（グループが1つのとき）。副作用が無いので、そのまま確かめられる。
    static func requests(for group: RotashGroup, now: Date = Date()) -> [UNNotificationRequest] {
        let calendar = Calendar.rotash
        let week = group.currentWeek
        var result: [UNNotificationRequest] = []
        var reminderDates = Set<Date>()

        for slot in week.slots.sorted(by: { $0.dayIndex < $1.dayIndex }) {
            guard let name = group.member(forDay: slot.dayIndex, in: week)?.name else { continue }

            // 朝の1通（もう8時を過ぎた日は出さない。夜の1通はそれとは別に考える）。
            if let date = fireDate(dayIndex: slot.dayIndex,
                                   weekStart: week.startDate,
                                   hour: morningHour,
                                   calendar: calendar),
               date > now {
                let content = UNMutableNotificationContent()
                content.title = "TODAY"
                content.body = String(localized: "今日は \(name.uppercased())")
                content.sound = .default

                result.append(request(id: "\(prefix)\(group.id.uuidString)-\(stamp(week.startDate))-\(slot.dayIndex)",
                                      date: date,
                                      content: content,
                                      calendar: calendar))
            }

            // 自分の番で、まだ撮っていなければ、夜にもう一度だけ。
            if let evening = reminderDate(for: slot, in: group, now: now, calendar: calendar) {
                reminderDates.insert(evening)
                result.append(request(id: "\(reminderPrefix)\(group.id.uuidString)-\(stamp(week.startDate))-\(slot.dayIndex)",
                                      date: evening,
                                      content: reminderContent(groupNames: []),
                                      calendar: calendar))
            }
        }

        // 日曜の夜。7枚そろっていても、撮れなかった日があっても、その週は決着している。
        // 「完成した瞬間」を全員に届けるにはプッシュが要るので、そこは後で。
        if let date = fireDate(dayIndex: 6,
                               weekStart: week.startDate,
                               hour: weekEndHour,
                               calendar: calendar),
           date > now,
           !reminderDates.contains(date) {
            let content = UNMutableNotificationContent()
            content.title = "THIS WEEK"
            content.body = String(localized: "今週の Rotash")
            content.sound = .default

            result.append(request(id: "\(weekEndPrefix)\(group.id.uuidString)-\(stamp(week.startDate))",
                                  date: date,
                                  content: content,
                                  calendar: calendar))
        }

        return result
    }

    // MARK: - 夜の1通

    /// 夜の1通を出す時刻。自分の番で、まだ撮っていない日だけ。それ以外は nil。
    private static func reminderDate(for slot: Slot,
                                     in group: RotashGroup,
                                     now: Date,
                                     calendar: Calendar) -> Date? {
        let week = group.currentWeek
        guard group.isMyDay(slot.dayIndex, in: week), !slot.isFilled,
              let evening = fireDate(dayIndex: slot.dayIndex, weekStart: week.startDate,
                                     hour: reminderHour, calendar: calendar),
              evening > now
        else { return nil }
        return evening
    }

    /// 掛け持ちしていて、同じ夜に番が重なったグループは、名前を並べて1通にする。
    private static func reminderContent(groupNames: [String]) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "TODAY"
        content.body = groupNames.isEmpty
            ? String(localized: "今日はあなたの番です。まだ撮れます")
            : String(localized: "今日はあなたの番です。まだ撮れます（\(groupNames.joined(separator: " / "))）")
        content.sound = .default
        return content
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
