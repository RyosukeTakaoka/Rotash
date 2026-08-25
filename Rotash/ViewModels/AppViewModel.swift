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

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?

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

        let newGroup = RotashGroup(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ROTASH" : name,
            inviteCode: InviteCode.generate(),
            members: members,
            myMemberID: me.id,
            currentWeek: Self.makeFirstWeek(memberIDs: members.map(\.id))
        )
        group = newGroup
        persist()
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
            currentWeek: Self.makeFirstWeek(memberIDs: [me.id])
        )
        group = newGroup
        persist()

        // 同期が有効なら、招待コードだけで今週の作品とメンバーが揃う。
        // 未設定のときはバトンを受け取るまでローカルのまま。
        Task {
            await sync()
            // 参加した本人を今週の担当に入れる（未公開の未来の枠だけを組み替える）。
            joinCurrentWeekIfPossible()
        }
    }

    /// 同期で受け取ったメンバー一覧に自分が居なかった場合に、自分を今週へ入れる。
    private func joinCurrentWeekIfPossible() {
        guard var current = group, let me = current.me else { return }
        let hasTurnThisWeek = current.currentWeek.slots.contains { $0.assigneeID == me.id }
        guard !hasTurnThisWeek else { return }
        replanFutureDays(&current, joining: me.id)
        group = current
        persist()
        Task { await sync() }
    }

    func addMember(name: String) {
        let cleaned = Self.tidy(name)
        guard var current = group, !cleaned.isEmpty else { return }
        guard !current.members.contains(where: { $0.name.caseInsensitiveCompare(cleaned) == .orderedSame }) else { return }

        let newMember = Member(name: cleaned)
        current.members.append(newMember)
        // 途中参加でも今週から作品づくりに参加してもらう。
        replanFutureDays(&current, joining: newMember.id)
        group = current
        persist()
    }

    /// メンバーが増えたときに、まだ公開していない未来の担当だけを組み替える。
    ///
    /// 未来の担当者はそもそも誰にも見せていないので、内部で組み替えても
    /// 「予定が変更された」という見え方にはならない。この性質を使って途中参加者を今週に入れる。
    /// 過去と今日の担当・写真には絶対に触らない。
    ///
    /// - Parameter joining: 途中参加した人。参加後の最初の枠を優先的に割り当てる。
    private func replanFutureDays(_ current: inout RotashGroup, joining newMemberID: UUID? = nil) {
        guard !current.members.isEmpty else { return }
        let today = Calendar.dayIndex(for: Date(), weekStart: current.currentWeek.startDate)

        // 再計算してよいのは「今日より後」の枠だけ。
        let futureDays = current.currentWeek.slots
            .filter { $0.dayIndex > today && !$0.isFilled }
            .map(\.dayIndex)
        guard !futureDays.isEmpty else { return }

        var history: [UUID: Int] = [:]
        for week in current.archive {
            for slot in week.slots {
                if let id = slot.assigneeID { history[id, default: 0] += 1 }
            }
        }
        for slot in current.currentWeek.slots where slot.dayIndex <= today {
            if let id = slot.assigneeID { history[id, default: 0] += 1 }
        }

        current.currentWeek = WeekPlanner.planned(week: current.currentWeek,
                                                  memberIDs: current.members.map(\.id),
                                                  history: history,
                                                  previousWeek: current.archive.first,
                                                  days: futureDays,
                                                  firstDayPriority: newMemberID)
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
        current.currentWeek = WeekPlanner.planned(week: .full(startDate: start),
                                                  memberIDs: current.members.map(\.id),
                                                  history: history,
                                                  previousWeek: finished)
        group = current
        persist()
    }

    /// 担当者を持たない古い保存データを、新しい担当者モデルへ移す。
    /// すでに撮影済みの枠は、実際に撮った人をその日の担当者として確定させるので、
    /// 進行中の作品の見え方は変わらない。
    private func migrateAssignmentsIfNeeded() {
        guard var current = group, !current.members.isEmpty else { return }
        guard current.currentWeek.slots.contains(where: { $0.assigneeID == nil }) else { return }

        let memberIDs = current.members.map(\.id)
        var week = current.currentWeek
        var history: [UUID: Int] = [:]

        for index in week.slots.indices {
            guard week.slots[index].assigneeID == nil else { continue }
            if let taken = week.slots[index].takenByMemberID, memberIDs.contains(taken) {
                week.slots[index].assigneeID = taken
                history[taken, default: 0] += 1
            }
        }

        let openDays = week.slots.filter { $0.assigneeID == nil }.map(\.dayIndex)
        if !openDays.isEmpty {
            week = WeekPlanner.planned(week: week,
                                       memberIDs: memberIDs,
                                       history: history,
                                       previousWeek: current.archive.first,
                                       days: openDays)
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
        persist()
    }

    // MARK: - サーバー同期

    var isSyncEnabled: Bool { RotashSyncService.isEnabled }

    /// サーバーと突き合わせる。未設定なら何もしない（ローカルのみで動き続ける）。
    /// 失敗しても手元のデータはそのままなので、次に開いたときに再試行される。
    func sync(showingError: Bool = false) async {
        guard RotashSyncService.isEnabled, let current = group, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let merged = try await RotashSyncService.sync(group: current)
            group = merged
            lastSyncedAt = Date()
            rollWeekIfNeeded()
            persist()
        } catch {
            if showingError { alertMessage = error.localizedDescription }
        }
    }

    // MARK: -

    private func persist() {
        store.save(group)
    }
}
