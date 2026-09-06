import Foundation
import SwiftUI

enum PortraitSheet: String, Identifiable {
    case create, join, settings
    var id: String { rawValue }
}

enum RotashError: LocalizedError {
    case noGroup

    var errorDescription: String? {
        switch self {
        case .noGroup:
            return "先に Rotash を作るか、招待コードで参加してください。"
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {

    @Published private(set) var group: RotashGroup?

    /// 検証用。ONにすると当番日以外の空き枠も撮れる（体験確認を優先するためのMVP用スイッチ）。
    @Published var freeShooting: Bool {
        didSet { UserDefaults.standard.set(freeShooting, forKey: Keys.freeShooting) }
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
    @Published private(set) var lastSyncedAt: Date?
    /// 同期でうまくいかなかったことがあれば、その内容。無言で失敗させないための表示用。
    @Published private(set) var syncNote: String?

    /// 同期中に来た次の同期要求。捨てずに終わってから走らせる。
    private var syncAgainWhenFinished = false

    private let store: RotashStore

    private enum Keys {
        static let freeShooting = "rotash.freeShooting"
    }

    init(store: RotashStore = FileRotashStore()) {
        self.store = store
        self.freeShooting = UserDefaults.standard.bool(forKey: Keys.freeShooting)
        self.group = store.load()
        migrateAssignmentsIfNeeded()
        rollWeekIfNeeded()
        applyAudit()
    }

    // MARK: - Derived

    var hasGroup: Bool { group != nil }

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
    func canShoot(dayIndex: Int) -> Bool {
        guard let group, let slot = group.currentWeek.slot(at: dayIndex) else { return false }
        // 撮り直しは今は仮で無効。RotashFeatureFlags.allowRetake を true にすれば
        // このガードだけで撮り直し（ライブビュー優先表示・SHOOT/RETAKE表示含む）が復活する。
        if slot.isFilled && !RotashFeatureFlags.allowRetake { return false }
        if freeShooting { return true }
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

    func createRotash(name: String, memberNames: [String]) {
        let cleanedNames = memberNames
            .map { Self.tidy($0) }
            .filter { !$0.isEmpty }
        guard !cleanedNames.isEmpty else { return }

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
        group = newGroup
        persist()
        prepareNotifications()
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

        let me = Member(name: name)
        let newGroup = RotashGroup(
            name: "ROTASH",
            inviteCode: normalized,
            members: [me],
            myMemberID: me.id,
            currentWeek: Self.makeJoiningWeek(memberID: me.id)
        )
        group = newGroup
        persist()
        pendingJoinCode = nil
        prepareNotifications()

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
    private func applyAudit() -> Bool {
        guard let current = group else { return false }
        let repaired = AssignmentAudit.repaired(current)
        guard repaired.currentWeek != current.currentWeek else { return false }
        group = repaired
        persist()
        return true
    }

    /// いま自分の端末が見ている担当表の照合コード。
    /// 同じ担当表ならどの端末でも同じ文字列になるので、見くらべれば食い違いに気づける。
    var assignmentFingerprint: String? {
        group.map { AssignmentAudit.fingerprint($0.currentWeek) }
    }

    func addMember(name: String) {
        let cleaned = Self.tidy(name)
        guard var current = group, !cleaned.isEmpty else { return }
        guard !current.members.contains(where: { $0.name.caseInsensitiveCompare(cleaned) == .orderedSame }) else { return }

        let newMember = Member(name: cleaned)
        current.members.append(newMember)
        group = current
        // 途中参加でも今週から作品づくりに参加してもらう。未来の枠の組み直しは検査が行う。
        applyAudit()
        persist()
        Task { await sync() }
    }

    func deleteRotash() {
        if let current = group {
            let weeks = [current.currentWeek] + current.archive
            for week in weeks {
                for slot in week.slots {
                    if let filename = slot.photoFilename { PhotoStore.shared.delete(filename) }
                }
            }
        }
        group = nil
        store.save(nil)
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
            guard group == nil else {
                alertMessage = "すでに Rotash に参加しています。"
                return
            }
            pendingJoinCode = code
            activeSheet = .join

        case let .create(origin):
            // 発行元は、まだグループを持っていなくても覚えておく。
            // 実際に作られたときに記録され、K を測る手がかりになる。
            pendingOriginGroupID = origin
            guard group == nil else { return }
            activeSheet = .create
        }
    }

    // MARK: - 通知

    /// 通知の許可を求める。起動直後ではなく、グループができてから聞く
    /// （まだ何も通知するものが無いうちに聞いても断られるだけなので）。
    private func prepareNotifications() {
        Task {
            _ = await NotificationScheduler.requestAuthorizationIfNeeded()
            NotificationScheduler.reschedule(for: group)
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

    func attachPhoto(_ data: Data, toDay dayIndex: Int) {
        guard var current = group,
              let index = current.currentWeek.slots.firstIndex(where: { $0.dayIndex == dayIndex }),
              let filename = try? PhotoStore.shared.save(data)
        else { return }

        if let old = current.currentWeek.slots[index].photoFilename {
            PhotoStore.shared.delete(old)
        }
        current.currentWeek.slots[index].photoFilename = filename
        current.currentWeek.slots[index].photoURL = nil      // 撮り直したら URL も取り直す
        current.currentWeek.slots[index].capturedAt = Date()
        current.currentWeek.slots[index].takenByMemberID = current.myMemberID
        group = current
        persist()

        // 撮ったらすぐ他の人に届くように同期する。失敗しても写真は手元に残る。
        Task { await sync() }
    }

    // MARK: - Week rollover

    /// 月曜になったら自動的に次の週へ。ユーザーが「新しい週を作る」操作は無い。
    /// 終わった週はそのまま Memories（archive）へ落ちる。
    func rollWeekIfNeeded() {
        guard var current = group else { return }
        let start = Calendar.startOfWeek()
        guard current.currentWeek.startDate < start else { return }

        let finished = current.currentWeek
        // 担当履歴は「入れ替える前」に取る（currentWeek と archive の二重計上を避ける）。
        let history = current.cumulativeAssignmentCounts

        if finished.filledCount > 0 {
            current.archive.insert(finished, at: 0)
        }

        // 週途中スタートだった初回の翌週からは、通常どおり月曜〜日曜の 7 枚に戻る。
        //
        // 種を渡して端末に依存しない計算にする。週送りは各端末がそれぞれ勝手に走らせるので、
        // ランダムだと端末ごとに違う担当表ができ、同期が届くまでのあいだ
        // 全員が「今日は自分の担当」と表示されてしまう（そして同じ日を2人で撮る）。
        let memberIDs = current.members.map(\.id)
        current.currentWeek = WeekPlanner.planned(week: .full(startDate: start),
                                                  memberIDs: memberIDs,
                                                  history: history,
                                                  previousWeek: finished,
                                                  seed: AssignmentPlanner.seed(
                                                      groupID: current.id,
                                                      weekStart: start,
                                                      memberIDs: memberIDs))
        group = current
        persist()
    }

    /// 担当者を持たない古い保存データを、新しい担当者モデルへ移す。
    /// すでに撮影済みの枠は、実際に撮った人をその日の担当者として確定させるので、
    /// 進行中の作品の見え方は変わらない。
    private func migrateAssignmentsIfNeeded() {
        guard var current = group, !current.members.isEmpty else { return }

        let needsAssignee = current.currentWeek.slots.contains { $0.assigneeID == nil }
        // 決定時刻を持たない担当は「まだ誰とも合意していない仮のもの」という印として扱う。
        // 決定時刻そのものが無かった頃の保存データはその印と見分けがつかないので、
        // ここで埋めておく。入れる値は週の開始日 — 実際の決定より必ず古く、
        // どの端末で開いても同じ値になるので、これで新旧の判定が狂わない。
        let needsTimestamp = current.currentWeek.slots.contains {
            $0.assigneeID != nil && $0.assignedAt == nil
        }
        guard needsAssignee || needsTimestamp else { return }

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
                                                                    salt: "migrate"))
        }

        current.currentWeek = week
        group = current
        persist()
    }

    // MARK: - Baton (端末間の受け渡し)

    func exportBaton() throws -> URL {
        guard let group else { throw RotashError.noGroup }
        return try BatonTransfer.export(group: group)
    }

    func importBaton(from url: URL) throws {
        let bundle = try BatonTransfer.read(from: url)
        guard let current = group else { throw RotashError.noGroup }
        guard current.inviteCode == bundle.inviteCode else {
            throw BatonTransferError.codeMismatch(expected: current.inviteCode, found: bundle.inviteCode)
        }

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
        guard RotashSyncService.isEnabled, group != nil else { return }

        // 同期中に撮影されたときなど、重なった要求を捨てずに後から必ず走らせる。
        if isSyncing {
            syncAgainWhenFinished = true
            return
        }

        isSyncing = true
        await performSync(showingError: showingError)
        isSyncing = false

        if syncAgainWhenFinished {
            syncAgainWhenFinished = false
            await sync()
        }
    }

    private func performSync(showingError: Bool) async {
        guard let current = group else { return }
        do {
            let outcome = try await RotashSyncService.sync(group: current)
            group = outcome.group
            lastSyncedAt = Date()

            if outcome.failedUploads > 0 {
                let reason = outcome.failureReason ?? ""
                syncNote = "写真 \(outcome.failedUploads) 枚を送れませんでした。\(reason)"
                if showingError { alertMessage = syncNote }
            } else {
                syncNote = nil
            }

            rollWeekIfNeeded()

            // 突き合わせた直後に必ず検査する。ここが「食い違ったまま固定されない」
            // ことの担保で、途中参加した人が今週の残りに入るのもここ。
            // 直したなら、その結果をもう一度みんなに共有する必要がある。
            // 検査は同じ状態に何度かけても結果が変わらないので、これで堂々巡りにはならない。
            if applyAudit() { syncAgainWhenFinished = true }

            persist()
        } catch {
            syncNote = error.localizedDescription
            if showingError { alertMessage = error.localizedDescription }
        }
    }

    // MARK: -

    private func persist() {
        store.save(group)
        // 担当が変わりうる操作はすべてここを通る（作成・参加・途中参加・週送り・同期）。
        // 差分で消そうとすると消し忘れた古い名前が朝に届くので、毎回まとめて組み直す。
        NotificationScheduler.reschedule(for: group)
    }
}
