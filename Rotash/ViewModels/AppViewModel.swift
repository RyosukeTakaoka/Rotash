import Foundation
import SwiftUI

enum PortraitSheet: String, Identifiable {
    /// shoot は縦持ちで撮る画面（全画面で出す。ほかはシート）。
    case create, join, settings, shoot
    var id: String { rawValue }
}

enum RotashError: LocalizedError {
    case noGroup

    var errorDescription: String? {
        switch self {
        case .noGroup:
            return String(localized: "先に Rotash を作るか、招待コードで参加してください。")
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {

    /// 掛け持ちしているグループすべて。
    @Published private(set) var groups: [RotashGroup] = []
    /// いま開いているグループ。
    @Published private(set) var currentGroupID: UUID?

    /// いま開いているグループ。画面も操作も、ここを相手にする。
    ///
    /// 書き込むと、掛け持ちしているグループのうち「いま開いているもの」が置き換わる。
    /// 同期で相手と突き合わせると ID が変わることがある（参加した直後など）ので、
    /// 置き換えたあとの ID を開いているグループとして覚え直す。nil を入れると、そのグループを外す。
    private(set) var group: RotashGroup? {
        get { currentIndex.map { groups[$0] } }
        set {
            if let newValue {
                if let index = currentIndex {
                    groups[index] = newValue
                } else {
                    groups.append(newValue)
                }
                currentGroupID = newValue.id
            } else if let index = currentIndex {
                groups.remove(at: index)
                currentGroupID = groups.first?.id
            }
        }
    }

    /// いま開いているグループの位置。覚えている ID が見つからなければ先頭。
    private var currentIndex: Int? {
        if let id = currentGroupID, let index = groups.firstIndex(where: { $0.id == id }) { return index }
        return groups.isEmpty ? nil : 0
    }

    @Published var alertMessage: String?

    /// 縦画面で開いているシート。
    /// View の @State に持たせると、キーボードなどで View が作り直されたときに
    /// 入力中のシートが勝手に閉じてしまうので、ここで保持する。
    @Published var activeSheet: PortraitSheet?

    /// リンクから来たときに、参加画面へ先に渡しておく招待コード。
    @Published var pendingJoinCode: String?

    /// 共有された作品から来たときの、発行元グループ ID。
    /// グループを作る瞬間まで持っておき、作られた時点で記録する。
    private var pendingOriginGroupID: UUID?

    @Published private(set) var isSyncing = false
    /// グループごとの、最後に同期できた時刻と、うまくいかなかったことの内容。
    /// 掛け持ちしているグループを順に同期するので、1つにまとめると最後のグループの結果で上書きされてしまう。
    @Published private var syncedAtByGroup: [UUID: Date] = [:]
    @Published private var syncNoteByGroup: [UUID: String] = [:]

    /// いま開いているグループを最後に同期できた時刻。
    var lastSyncedAt: Date? { group.flatMap { syncedAtByGroup[$0.id] } }
    /// 同期でうまくいかなかったことがあれば、その内容。無言で失敗させないための表示用。
    var syncNote: String? { group.flatMap { syncNoteByGroup[$0.id] } }

    /// 同期中に来た次の同期要求。捨てずに終わってから走らせる。
    private var syncAgainWhenFinished = false

    private let store: RotashStore

    init(store: RotashStore = FileRotashStore()) {
        self.store = store
        let library = store.load()
        self.groups = library.groups
        self.currentGroupID = library.currentGroupID ?? library.groups.first?.id
        migrateAssignmentsIfNeeded()
        rollWeekIfNeeded()
        for id in groups.map(\.id) { applyAudit(groupID: id) }
    }

    // MARK: - 掛け持ち

    /// 開くグループを切り替える。
    func switchGroup(to id: UUID) {
        guard groups.contains(where: { $0.id == id }), currentGroupID != id else { return }
        currentGroupID = id
        persist()
        Task { await sync() }
    }

    /// 同じ招待コードのグループにすでに入っているか。入っていれば、そのグループ。
    func joinedGroup(withCode code: String) -> RotashGroup? {
        let normalized = InviteCode.normalize(code)
        return groups.first { $0.inviteCode == normalized }
    }

    // MARK: - Derived

    var hasGroup: Bool { !groups.isEmpty }

    var todayIndex: Int {
        Calendar.dayIndex(for: Date(), weekStart: group?.currentWeek.startDate)
    }

    /// 本当の担当者。撮影可否の判定など、内部の判断だけに使う。
    func assignee(forDay dayIndex: Int) -> Member? {
        guard let group else { return nil }
        return group.member(forDay: dayIndex, in: group.currentWeek)
    }

    /// 表示用の担当者。まだその日が来ていない枠は誰にも見せない。
    /// 「次に誰が撮るのか分からない」という不確実さ自体が Rotash の体験なので、
    /// 週の頭に全員分の担当を公開しない。
    func revealedAssignee(forDay dayIndex: Int) -> Member? {
        guard dayIndex <= todayIndex else { return nil }
        return assignee(forDay: dayIndex)
    }

    func isMyDay(_ dayIndex: Int) -> Bool {
        guard let group else { return false }
        return group.isMyDay(dayIndex, in: group.currentWeek)
    }

    /// 撮影できるかどうか。閲覧には一切関係しない — 7分割は誰でも常に全部見える。
    /// 撮れるのはその日の担当者だけ。
    func canShoot(dayIndex: Int, now: Date = Date()) -> Bool {
        guard let group, let slot = group.currentWeek.slot(at: dayIndex) else { return false }
        // 撮り直しは、撮った直後の短い時間だけ（RotashFeatureFlags.retakeWindowSeconds）。
        // RotashFeatureFlags.allowRetake を true にすれば、時間に関係なく撮り直せる。
        if slot.isFilled && !RotashFeatureFlags.allowRetake && !canRetake(slot, now: now) { return false }
        guard group.isMyDay(dayIndex, in: group.currentWeek) else { return false }
        // 仮の担当（決定時刻を持たない = まだ誰とも突き合わせていない）では撮らせない。
        // 他にメンバーが居ると分かっているのに自分の判断だけで撮ると、
        // 同じ日を二人が撮ってしまい、あとの突き合わせで片方の写真が消える。
        if slot.assignedAt == nil && group.members.count > 1 { return false }
        // 未来の日は撮れない。
        // 過ぎた日も撮れない — 撮られなかった日は No Shot として確定する。
        if RotashFeatureFlags.allowCatchUpShooting {
            return dayIndex <= todayIndex
        }
        return dayIndex == todayIndex
    }

    /// 撮った直後の撮り直しができる枠か。撮った本人で、最初の1枚から規定の秒数以内。
    func canRetake(_ slot: Slot, now: Date = Date()) -> Bool {
        retakeDeadline(for: slot).map { now < $0 } ?? false
    }

    /// 撮り直しの締め切り。撮り直しの対象でなければ nil。
    func retakeDeadline(for slot: Slot) -> Date? {
        let window = RotashFeatureFlags.retakeWindowSeconds
        guard window > 0,
              let group,
              slot.photoFilename != nil,
              let taker = slot.takenByMemberID, taker == group.myMemberID,
              let first = slot.capturedAt
        else { return nil }
        return first.addingTimeInterval(window)
    }

    /// 今週のうち、いちばん遅い撮り直しの締め切り（撮れるかどうかは問わない）。
    /// 画面の時計を「締め切りが過ぎるまで」進めるために使う。
    var latestRetakeDeadline: Date? {
        group?.currentWeek.slots.compactMap { retakeDeadline(for: $0) }.max()
    }

    /// いま撮り直せる枠と、その締め切り。画面の残り秒数と RETAKE ボタンに使う。
    ///
    /// 今週の枠から探す（撮り直しを許す設定では今日以外の枠もありうる）。複数あるときは、いちばん最近撮った枠。
    /// 週の最後の1枚を撮って週が「完成」になった直後も、ここは撮り直せる枠を返す。
    func retakeWindow(now: Date = Date()) -> (dayIndex: Int, deadline: Date)? {
        guard let group else { return nil }
        return group.currentWeek.slots
            .compactMap { slot -> (dayIndex: Int, deadline: Date)? in
                guard slot.isFilled,
                      let deadline = retakeDeadline(for: slot),
                      now < deadline,
                      canShoot(dayIndex: slot.dayIndex, now: now)
                else { return nil }
                return (slot.dayIndex, deadline)
            }
            .max { $0.deadline < $1.deadline }
    }

    /// 縦のホームに「縦のまま撮る」を出すか。
    /// 今日の担当でまだ撮っていないとき、または撮った直後で撮り直せるとき。
    var canShootTodayInPortrait: Bool {
        // 週の途中から始めた最初の週で枠が1〜2つしかないと、1枠が横に広く、縦に撮るとかえって狭く写る。
        guard RotashFeatureFlags.allowsPortraitShooting,
              let week = group?.currentWeek, week.slots.count > 2,
              let slot = week.slot(at: todayIndex)
        else { return false }
        if !slot.isFilled { return autoActiveDay == todayIndex }
        return canShoot(dayIndex: todayIndex)
    }

    /// タップしなくても最初からカメラが開いている枠。
    /// まだ誰も撮っていない「今日の担当日」だけを自動で開く。
    /// 撮影済みの枠（撮り直し）は、タップして選ぶまでは自分の写真をそのまま見せる。
    var autoActiveDay: Int? {
        guard let group,
              canShoot(dayIndex: todayIndex),
              let todaySlot = group.currentWeek.slot(at: todayIndex),
              !todaySlot.isFilled
        else { return nil }
        return todayIndex
    }

    // MARK: - Create / Join

    /// 名前を整える。
    /// 入力中に切り詰めると日本語変換が壊れるので、長さを詰めるのは確定したこの時点だけにする。
    private static func tidy(_ name: String, limit: Int = 20) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    /// - Returns: 作ったグループの ID。名前が空などで作らなかったときは nil。
    @discardableResult
    func createRotash(name: String, memberNames: [String]) -> UUID? {
        let cleanedNames = memberNames
            .map { Self.tidy($0) }
            .filter { !$0.isEmpty }
        guard !cleanedNames.isEmpty else { return nil }

        let members = cleanedNames.map { Member(name: $0) }
        let me = members[0]

        var newGroup = RotashGroup(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ROTASH" : name,
            inviteCode: InviteCode.generate(),
            members: members,
            myMemberID: me.id,
            currentWeek: Self.makeFirstWeek(memberIDs: members.map(\.id))
        )
        newGroup.originGroupID = pendingOriginGroupID
        pendingOriginGroupID = nil
        // 掛け持ちに加えて、作ったグループを開く。
        groups.append(newGroup)
        currentGroupID = newGroup.id
        persist()
        prepareNotifications()
        AnalyticsService.groupCreated(fromOriginGroup: newGroup.originGroupID != nil)
        return newGroup.id
    }

    /// 最初の週。週の途中で始めた場合は、その日から日曜までを 1 つの作品にする。
    /// 「作った曜日が毎週の開始曜日になる」わけではなく、これは初回だけの特殊ケース。
    private static func makeFirstWeek(memberIDs: [UUID], now: Date = Date()) -> RotashWeek {
        let weekStart = Calendar.startOfWeek(for: now)
        let today = Calendar.dayIndex(for: now, weekStart: weekStart)
        let week = RotashWeek.starting(atDayIndex: today, startDate: weekStart)
        return WeekPlanner.planned(week: week,
                                   memberIDs: memberIDs,
                                   history: [:],
                                   previousWeek: nil)
    }

    func joinRotash(code: String, myName: String) {
        let normalized = InviteCode.normalize(code)
        let name = Self.tidy(myName)
        guard normalized.count == 6, !name.isEmpty else { return }
        // 同じグループに二重に入らない（入っていれば、そのグループを開くだけ）。
        if let existing = joinedGroup(withCode: normalized) {
            currentGroupID = existing.id
            pendingJoinCode = nil
            persist()
            return
        }

        let me = Member(name: name)
        let newGroup = RotashGroup(
            name: "ROTASH",
            inviteCode: normalized,
            members: [me],
            myMemberID: me.id,
            currentWeek: Self.makeJoiningWeek(memberID: me.id)
        )
        groups.append(newGroup)
        currentGroupID = newGroup.id
        persist()
        pendingJoinCode = nil
        prepareNotifications()
        AnalyticsService.groupJoined()

        // 同期が有効なら、招待コードだけで今週の作品とメンバーが揃う。
        // 未設定のときはバトンを受け取るまでローカルのまま。
        // 参加した本人を今週の担当に入れるのは同期のあとの検査（applyAudit）の仕事。
        Task { await sync() }
    }

    /// 参加した直後の、まだ誰とも突き合わせていない週。
    ///
    /// ここで担当を「確定」させてはいけない。
    /// 参加した端末はまだ他のメンバーを一人も知らないので、素直に計算すると
    /// 「今日から日曜まで全部自分の担当」という週ができあがる。
    /// それを確定した担当（= assignedAt を持つ）として作ってしまうと、同期のマージが
    /// 「あとから決まった方が勝つ」ルールなので、サーバー上の本当の担当を上書きしてしまう。
    /// 参加した人数だけ上書きが起きるため、全員が「今日は自分の担当」と表示される。
    ///
    /// そこで assignedAt を付けない = **仮の担当**という印にする。
    /// 仮の担当は、本物の担当（assignedAt を持つ）にマージで必ず負ける。
    /// まだ誰とも繋がれていないあいだ（同期未設定・通信失敗）だけ、この仮の担当で撮れる。
    private static func makeJoiningWeek(memberID: UUID, now: Date = Date()) -> RotashWeek {
        let weekStart = Calendar.startOfWeek(for: now)
        let today = Calendar.dayIndex(for: now, weekStart: weekStart)
        var week = RotashWeek.starting(atDayIndex: today, startDate: weekStart)
        for index in week.slots.indices {
            week.slots[index].assigneeID = memberID
            week.slots[index].assignedAt = nil
        }
        return week
    }

    /// 担当表を検査して、直せるところを直す。
    ///
    /// 端末ごとに担当を計算する以上ズレは起きうるので、状態が変わったところでは必ず通す。
    /// 途中参加した人が今週の残りに入るのも、ここが引き受ける
    /// （「参加した端末が自分の枠を取りにいく」形をやめ、
    ///   「いまのメンバーで組み直したらこうなる」という計算だけにした。
    ///   誰が引き金を引いたかで結果が変わらないので、全端末が同じ表に行き着く）。
    ///
    /// - Returns: 直したところがあれば true。
    @discardableResult
    private func applyAudit(groupID: UUID? = nil) -> Bool {
        let id = groupID ?? group?.id
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        let current = groups[index]
        let repaired = AssignmentAudit.repaired(current)
        guard repaired.currentWeek != current.currentWeek else { return false }
        groups[index] = repaired
        persist()
        return true
    }

    /// いま自分の端末が見ている担当表の照合コード。
    /// 同じ担当表ならどの端末でも同じ文字列になるので、見くらべれば食い違いに気づける。
    var assignmentFingerprint: String? {
        group.map { AssignmentAudit.fingerprint($0.currentWeek) }
    }

    /// いま開いているグループから抜ける（この端末からそのグループと写真を消す）。
    /// ほかのグループに入っていれば、そちらを開く。
    func deleteRotash() {
        if var current = group {
            // 抜けたことを、ほかのメンバーに伝える（伝わると、まだ来ていない日の当番から外れる）。
            // この端末からはすぐ消すので、写真の上げ下ろしはせず、印だけをサーバーに載せる。
            if let index = current.members.firstIndex(where: { $0.id == current.myMemberID }) {
                current.members[index].leftAt = Date()
                let leaving = current
                Task { try? await RotashSyncService.publishLeave(of: leaving) }
            }
            let weeks = [current.currentWeek] + current.archive
            for week in weeks {
                for slot in week.slots {
                    if let filename = slot.photoFilename { PhotoStore.shared.delete(filename) }
                    if let filename = slot.reversePhotoFilename { PhotoStore.shared.delete(filename) }
                }
            }
        }
        group = nil
        persist()
    }

    // MARK: - リンクから入ってくる

    /// `rotash://` で開かれたときの入口。
    ///
    /// 2種類あり、意味がまったく違う。
    ///   join   … 誰かの空き枠に呼ばれた（個別に送られたリンク）
    ///   new    … 公開された作品を見て来た。自分たちのグループを作る側
    func handle(_ url: URL) {
        guard let destination = RotashLink.destination(for: url) else { return }

        switch destination {
        case let .join(code):
            // すでに入っているグループなら、そのグループを開くだけ。
            if let existing = joinedGroup(withCode: code) {
                currentGroupID = existing.id
                pendingJoinCode = nil
                persist()
                alertMessage = String(localized: "このグループにはもう参加しています。")
                return
            }
            pendingJoinCode = code
            activeSheet = .join

        case let .create(origin):
            // 発行元は、まだグループを持っていなくても覚えておく。
            // 実際に作られたときに記録され、K を測る手がかりになる。
            pendingOriginGroupID = origin
            // 掛け持ちできるので、すでにグループがあっても新しく作れる。
            activeSheet = .create
        }
    }

    // MARK: - 通知

    /// 通知の許可を求める。起動直後ではなく、グループができてから聞く
    /// （まだ何も通知するものが無いうちに聞いても断られるだけなので）。
    private func prepareNotifications() {
        Task {
            _ = await NotificationScheduler.requestAuthorizationIfNeeded()
            NotificationScheduler.reschedule(for: groups)
        }
    }

    // MARK: - 週のタイトル

    /// タイトルを付けられる週。
    ///
    /// 付けられるのは **7枚目を撮った本人だけ**。全員が書けるようにするとコメント欄になる。
    /// 対象は今週と、直近の1本（日曜の夜に決着してそのまま月曜をまたいだ場合）。
    var titlableWeek: RotashWeek? {
        guard let group else { return nil }
        let candidates = [group.currentWeek] + Array(group.archive.prefix(1))
        return candidates.first { week in
            week.isFinished
                && (week.title ?? "").isEmpty
                && week.lastCapturedSlot?.takenByMemberID == group.myMemberID
        }
    }

    /// タイトルを一度だけ書き込む。あとから編集はしない。その週の記録なので。
    func setTitle(_ raw: String, for week: RotashWeek) {
        guard var current = group, titlableWeek?.id == week.id else { return }
        let cleaned = String(raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(RotashWeek.titleLimit))
        guard !cleaned.isEmpty else { return }

        if current.currentWeek.id == week.id {
            current.currentWeek.title = cleaned
        } else if let index = current.archive.firstIndex(where: { $0.id == week.id }) {
            current.archive[index].title = cleaned
        } else {
            return
        }

        group = current
        persist()
        Task { await sync() }
    }

    // MARK: - Shooting

    /// - Parameters:
    ///   - data: 表の写真（撮るときに大きい画面に映っていた方）。
    ///   - front: 表を内カメで撮ったか。
    ///   - reverse: 裏の写真（シャッター側の丸に映っていた方）。撮れなかったときは nil。
    ///   - reverseFront: 裏を内カメで撮ったか。
    func attachPhoto(_ data: Data, toDay dayIndex: Int, front: Bool = false,
                     reverse: Data? = nil, reverseFront: Bool = true) {
        guard var current = group,
              let index = current.currentWeek.slots.firstIndex(where: { $0.dayIndex == dayIndex }),
              let filename = try? PhotoStore.shared.save(data)
        else { return }
        let reverseFilename = reverse.flatMap { try? PhotoStore.shared.save($0) }

        let previous = current.currentWeek.slots[index]
        let now = Date()
        // 自分が撮った直後の撮り直しなら「同じ1枚の新しい版」として扱い、
        // 最初に撮った時刻は変えない（撮り直せる時間が延びないように）。
        let isRetake = previous.isFilled
            && previous.takenByMemberID == current.myMemberID
            && previous.capturedAt != nil

        if let old = previous.photoFilename {
            PhotoStore.shared.delete(old)
        }
        if let old = previous.reversePhotoFilename {
            PhotoStore.shared.delete(old)
        }
        current.currentWeek.slots[index].photoFilename = filename
        current.currentWeek.slots[index].photoURL = nil      // 撮り直したら URL も取り直す
        current.currentWeek.slots[index].reversePhotoFilename = reverseFilename
        current.currentWeek.slots[index].reversePhotoURL = nil
        current.currentWeek.slots[index].reverseCapturedWithFront = reverseFilename == nil ? nil : reverseFront
        if isRetake {
            current.currentWeek.slots[index].retakeCount = (previous.retakeCount ?? 0) + 1
        } else {
            current.currentWeek.slots[index].capturedAt = now
            current.currentWeek.slots[index].retakeCount = nil
        }
        current.currentWeek.slots[index].takenByMemberID = current.myMemberID
        current.currentWeek.slots[index].capturedWithFront = front
        group = current
        persist()
        if isRetake, let first = previous.capturedAt {
            AnalyticsService.photoRetaken(secondsAfterFirst: Int(now.timeIntervalSince(first)))
        } else {
            AnalyticsService.photoCaptured(filledCount: current.currentWeek.filledCount)
        }

        // 撮ったらすぐ他の人に届くように同期する。失敗しても写真は手元に残る。
        Task { await sync() }
    }

    // MARK: - Week rollover

    /// 月曜になったら自動的に次の週へ。ユーザーが「新しい週を作る」操作は無い。
    /// 終わった週はそのまま Memories（archive）へ落ちる。
    func rollWeekIfNeeded() {
        var changed = false
        for index in groups.indices {
            if let rolled = Self.rolledWeek(groups[index]) {
                groups[index] = rolled
                changed = true
            }
        }
        if changed { persist() }
    }

    /// 週が変わっていれば、次の週に進めたグループ。変わっていなければ nil。
    private static func rolledWeek(_ group: RotashGroup) -> RotashGroup? {
        var current = group
        let start = Calendar.startOfWeek()
        guard current.currentWeek.startDate < start else { return nil }

        let finished = current.currentWeek
        // 担当履歴は「入れ替える前」に取る（currentWeek と archive の二重計上を避ける）。
        let history = current.cumulativeAssignmentCounts

        if finished.filledCount > 0 {
            current.archive.insert(finished, at: 0)
        }
        if finished.isComplete {
            AnalyticsService.weekCompleted(
                memberCount: current.members.count,
                isFirstWeek: current.archive.count == 1
            )
        }

        // 週途中スタートだった初回の翌週からは、通常どおり月曜〜日曜の 7 枚に戻る。
        //
        // 週送りは各端末がそれぞれ勝手に走らせる（月曜に最初に開いた瞬間に走る）ので、
        // ここを端末まかせにすると端末ごとに違う担当表ができる。同期が届くまでのあいだ
        // 全員が「今日は自分の担当」と表示され、同じ月曜を何人もが撮ってしまう。
        //
        //   種      … 同じメンバー・同じ週なら、どの端末でも同じ担当表になる
        //   決定時刻 … その週の開始日。どの端末で走らせても同じ値になるので、
        //             メンバーの把握がズレて違う表ができた場合でも「同着」になり、
        //             マージの同着処理で全端末が同じ側を選ぶ
        // 抜けた人には、次の週から当番を回さない。
        let active = current.activeMembers.map(\.id)
        let memberIDs = active.isEmpty ? current.members.map(\.id) : active
        current.currentWeek = WeekPlanner.planned(week: .full(startDate: start),
                                                  memberIDs: memberIDs,
                                                  history: history,
                                                  previousWeek: finished,
                                                  seed: AssignmentPlanner.seed(
                                                      groupID: current.id,
                                                      weekStart: start,
                                                      memberIDs: memberIDs),
                                                  decidedAt: start)
        return current
    }

    /// 担当者を持たない古い保存データを、新しい担当者モデルへ移す。
    /// すでに撮影済みの枠は、実際に撮った人をその日の担当者として確定させるので、
    /// 進行中の作品の見え方は変わらない。
    private func migrateAssignmentsIfNeeded() {
        var changed = false
        for index in groups.indices {
            if let migrated = Self.migratedAssignments(groups[index]) {
                groups[index] = migrated
                changed = true
            }
        }
        if changed { persist() }
    }

    /// 担当者を持たない古い保存データを移したグループ。移すものが無ければ nil。
    private static func migratedAssignments(_ group: RotashGroup) -> RotashGroup? {
        var current = group
        guard !current.members.isEmpty else { return nil }

        let needsAssignee = current.currentWeek.slots.contains { $0.assigneeID == nil }
        // 決定時刻を持たない担当は「まだ誰とも合意していない仮のもの」という印として扱う。
        // 決定時刻そのものが無かった頃の保存データはその印と見分けがつかないので、
        // ここで埋めておく。入れる値は週の開始日 — 実際の決定より必ず古く、
        // どの端末で開いても同じ値になるので、これで新旧の判定が狂わない。
        let needsTimestamp = current.currentWeek.slots.contains {
            $0.assigneeID != nil && $0.assignedAt == nil
        }
        guard needsAssignee || needsTimestamp else { return nil }

        let memberIDs = current.members.map(\.id)
        var week = current.currentWeek
        var history: [UUID: Int] = [:]

        for index in week.slots.indices {
            guard week.slots[index].assigneeID == nil else {
                if week.slots[index].assignedAt == nil {
                    week.slots[index].assignedAt = week.startDate
                }
                continue
            }
            if let taken = week.slots[index].takenByMemberID, memberIDs.contains(taken) {
                week.slots[index].assigneeID = taken
                week.slots[index].assignedAt = week.startDate
                history[taken, default: 0] += 1
            }
        }

        let openDays = week.slots.filter { $0.assigneeID == nil }.map(\.dayIndex)
        if !openDays.isEmpty {
            week = WeekPlanner.planned(week: week,
                                       memberIDs: memberIDs,
                                       history: history,
                                       previousWeek: current.archive.first,
                                       days: openDays,
                                       seed: AssignmentPlanner.seed(groupID: current.id,
                                                                    weekStart: week.startDate,
                                                                    memberIDs: memberIDs,
                                                                    salt: "migrate"),
                                       // 移行も端末ごとに走るので、決定時刻を端末共通にする。
                                       decidedAt: week.startDate)
        }

        current.currentWeek = week
        return current
    }

    // MARK: - Baton (端末間の受け渡し)

    func exportBaton() throws -> URL {
        guard let group else { throw RotashError.noGroup }
        return try BatonTransfer.export(group: group)
    }

    func importBaton(from url: URL) throws {
        let bundle = try BatonTransfer.read(from: url)
        guard let opened = group else { throw RotashError.noGroup }
        // 掛け持ちしているなら、同じ招待コードのグループに受け取る。
        guard let current = joinedGroup(withCode: bundle.inviteCode) else {
            throw BatonTransferError.codeMismatch(expected: opened.inviteCode, found: bundle.inviteCode)
        }
        currentGroupID = current.id

        BatonTransfer.materializePhotos(bundle)

        // バトンもサーバー同期も「相手の状態と突き合わせる」点は同じなので、同じ処理を使う。
        var incoming = RemoteGroupState(group: current)
        incoming.id = bundle.groupID
        incoming.name = bundle.groupName
        incoming.members = bundle.members
        incoming.currentWeek = bundle.week
        incoming.archive = []

        group = RotashMerge.merge(local: current, remote: incoming)
        rollWeekIfNeeded()
        // バトンで初めて相手を知った場合も、検査を通して今週の残りに入れる。
        // 同期で参加したときと同じ扱いにしないと、バトンで来た人だけ取り残される。
        applyAudit()
        persist()
    }

    // MARK: - サーバー同期

    var isSyncEnabled: Bool { RotashSyncService.isEnabled }

    /// サーバーと突き合わせる。未設定なら何もしない（ローカルのみで動き続ける）。
    /// 失敗しても手元のデータはそのままなので、次に開いたときに再試行される。
    func sync(showingError: Bool = false) async {
        guard RotashSyncService.isEnabled, !groups.isEmpty else { return }

        // 同期中に撮影されたときなど、重なった要求を捨てずに後から必ず走らせる。
        if isSyncing {
            syncAgainWhenFinished = true
            return
        }

        isSyncing = true
        // 掛け持ちしているグループを順に。開いていないグループの当番も、朝の通知に要るので取りに行く。
        // いま開いているグループを先にする（画面に出ているので）。
        let all = groups.map(\.id)
        let order = all.filter { $0 == currentGroupID } + all.filter { $0 != currentGroupID }
        for id in order {
            await performSync(groupID: id, showingError: showingError)
        }
        isSyncing = false

        if syncAgainWhenFinished {
            syncAgainWhenFinished = false
            await sync()
        }
    }

    private func performSync(groupID: UUID, showingError: Bool) async {
        guard let current = groups.first(where: { $0.id == groupID }) else { return }
        do {
            let outcome = try await RotashSyncService.sync(group: current)
            // 同期しているあいだに ID が変わった（バトンを受け取った）なら、招待コードで探し直す。
            // それでも見つからなければ、同期しているあいだに抜けたグループなので結果は捨てる。
            guard let index = groups.firstIndex(where: { $0.id == groupID })
                    ?? groups.firstIndex(where: { $0.inviteCode == current.inviteCode })
            else { return }
            let sentID = groups[index].id
            let result = keepingPhotosTakenDuringSync(outcome.group, sent: current, latest: groups[index])
            groups[index] = result
            // 突き合わせで ID が変わったら（参加した直後など）、開いているグループもそれに合わせる。
            if currentGroupID == sentID { currentGroupID = result.id }
            syncedAtByGroup[sentID] = nil
            syncedAtByGroup[result.id] = Date()
            syncNoteByGroup[sentID] = nil

            if outcome.failedUploads > 0 {
                let reason = outcome.failureReason ?? ""
                let note = String(localized: "写真 \(outcome.failedUploads) 枚を送れませんでした。\(reason)")
                syncNoteByGroup[result.id] = note
                if showingError, result.id == currentGroupID { alertMessage = note }
            } else {
                syncNoteByGroup[result.id] = nil
            }

            rollWeekIfNeeded()

            // 突き合わせた直後に必ず検査する。ここが「食い違ったまま固定されない」
            // ことの担保で、途中参加した人が今週の残りに入るのもここ。
            // 直したなら、その結果をもう一度みんなに共有する必要がある。
            // 検査は同じ状態に何度かけても結果が変わらないので、これで堂々巡りにはならない。
            if applyAudit(groupID: result.id) { syncAgainWhenFinished = true }

            persist()
        } catch {
            syncNoteByGroup[groupID] = error.localizedDescription
            if showingError, groupID == currentGroupID { alertMessage = error.localizedDescription }
        }
    }

    /// 同期は数秒かかる。そのあいだに撮った（撮り直した）写真は、同期に送った状態には入っていない。
    /// 結果をそのまま採ると撮ったばかりの写真が巻き戻るので、その枠だけ手元の今の状態を残し、
    /// もう一度同期してみんなに届ける。撮った直後の撮り直しでは、これがよく起きる。
    private func keepingPhotosTakenDuringSync(_ synced: RotashGroup,
                                              sent: RotashGroup,
                                              latest: RotashGroup) -> RotashGroup {
        guard latest.currentWeek.id == sent.currentWeek.id,
              synced.currentWeek.startDate == latest.currentWeek.startDate
        else { return synced }

        var result = synced
        for slot in latest.currentWeek.slots {
            let before = sent.currentWeek.slot(at: slot.dayIndex)
            guard slot.photoFilename != nil,
                  slot.photoFilename != before?.photoFilename,
                  let index = result.currentWeek.slots.firstIndex(where: { $0.dayIndex == slot.dayIndex })
            else { continue }
            result.currentWeek.slots[index] = slot
            syncAgainWhenFinished = true
        }
        return result
    }

    // MARK: -

    private func persist() {
        store.save(RotashLibrary(groups: groups, currentGroupID: currentGroupID))
        // 担当が変わりうる操作はすべてここを通る（作成・参加・途中参加・週送り・同期）。
        // 差分で消そうとすると消し忘れた古い名前が朝に届くので、毎回まとめて組み直す。
        NotificationScheduler.reschedule(for: groups)
    }
}
