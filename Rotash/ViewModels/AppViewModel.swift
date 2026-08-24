import Foundation
import SwiftUI

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

    private let store: RotashStore

    private enum Keys {
        static let freeShooting = "rotash.freeShooting"
    }

    init(store: RotashStore = FileRotashStore()) {
        self.store = store
        self.freeShooting = UserDefaults.standard.bool(forKey: Keys.freeShooting)
        self.group = store.load()
        rollWeekIfNeeded()
    }

    // MARK: - Derived

    var hasGroup: Bool { group != nil }

    var todayIndex: Int {
        Calendar.dayIndex(for: Date(), weekStart: group?.currentWeek.startDate)
    }

    func assignee(forDay dayIndex: Int) -> Member? {
        guard let group else { return nil }
        return group.member(forDay: dayIndex, in: group.currentWeek)
    }

    func isMyDay(_ dayIndex: Int) -> Bool {
        guard let group else { return false }
        return group.isMyDay(dayIndex, in: group.currentWeek)
    }

    func canShoot(dayIndex: Int) -> Bool {
        guard let group,
              let slot = group.currentWeek.slot(at: dayIndex),
              !slot.isFilled
        else { return false }
        if freeShooting { return true }
        guard group.isMyDay(dayIndex, in: group.currentWeek) else { return false }
        // 未来の日は撮れない。当番日を逃したぶんは追いつける。
        return dayIndex <= todayIndex
    }

    var shootableDays: [Int] {
        (0..<7).filter { canShoot(dayIndex: $0) }
    }

    /// 最初に選ばれる枠。今日が自分の当番ならそこ、なければ一番古い撮影可能な枠。
    var suggestedDay: Int? {
        let days = shootableDays
        if days.contains(todayIndex) { return todayIndex }
        return days.first
    }

    // MARK: - Create / Join

    func createRotash(name: String, memberNames: [String]) {
        let cleanedNames = memberNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedNames.isEmpty else { return }

        let members = cleanedNames.map { Member(name: $0) }
        let me = members[0]

        let newGroup = RotashGroup(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ROTASH" : name,
            inviteCode: InviteCode.generate(),
            members: members,
            myMemberID: me.id,
            currentWeek: .empty(startDate: Calendar.startOfWeek(), rotationOffset: 0)
        )
        group = newGroup
        persist()
    }

    func joinRotash(code: String, myName: String) {
        let normalized = InviteCode.normalize(code)
        let name = myName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 6, !name.isEmpty else { return }

        let me = Member(name: name)
        let newGroup = RotashGroup(
            name: "ROTASH",
            inviteCode: normalized,
            members: [me],
            myMemberID: me.id,
            currentWeek: .empty(startDate: Calendar.startOfWeek(), rotationOffset: 0)
        )
        group = newGroup
        persist()
    }

    func addMember(name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var current = group, !cleaned.isEmpty else { return }
        guard !current.members.contains(where: { $0.name.caseInsensitiveCompare(cleaned) == .orderedSame }) else { return }
        current.members.append(Member(name: cleaned))
        group = current
        persist()
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
        current.currentWeek.slots[index].capturedAt = Date()
        current.currentWeek.slots[index].takenByMemberID = current.myMemberID
        group = current
        persist()
    }

    // MARK: - Week rollover

    func rollWeekIfNeeded() {
        guard var current = group else { return }
        let start = Calendar.startOfWeek()
        guard current.currentWeek.startDate < start else { return }

        if current.currentWeek.filledCount > 0 {
            current.archive.insert(current.currentWeek, at: 0)
        }
        let offset = current.members.isEmpty
            ? 0
            : (current.currentWeek.rotationOffset + 7) % current.members.count
        current.currentWeek = .empty(startDate: start, rotationOffset: offset)
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
        guard var current = group else { throw RotashError.noGroup }
        guard current.inviteCode == bundle.inviteCode else {
            throw BatonTransferError.codeMismatch(expected: current.inviteCode, found: bundle.inviteCode)
        }

        BatonTransfer.materializePhotos(bundle)

        // メンバーは受け取った側を正とし、自分は名前で照合する。
        let myName = current.me?.name ?? ""
        var members = bundle.members
        if let match = members.first(where: { $0.name.caseInsensitiveCompare(myName) == .orderedSame }) {
            current.myMemberID = match.id
        } else if let me = current.me {
            members.append(me)
        }
        current.members = members
        current.id = bundle.groupID
        current.name = bundle.groupName

        let incoming = bundle.week
        if incoming.startDate == current.currentWeek.startDate {
            current.currentWeek = Self.merge(local: current.currentWeek, incoming: incoming)
        } else if incoming.startDate > current.currentWeek.startDate {
            if current.currentWeek.filledCount > 0 {
                current.archive.insert(current.currentWeek, at: 0)
            }
            current.currentWeek = incoming
        } else if incoming.filledCount > 0,
                  !current.archive.contains(where: { $0.startDate == incoming.startDate }) {
            current.archive.append(incoming)
            current.archive.sort { $0.startDate > $1.startDate }
        }

        group = current
        rollWeekIfNeeded()
        persist()
    }

    /// 同じ週を別々に撮っていた場合でも写真を落とさないように合流させる。
    static func merge(local: RotashWeek, incoming: RotashWeek) -> RotashWeek {
        var merged = incoming
        merged.id = local.id
        merged.slots = (0..<7).map { dayIndex in
            let localSlot = local.slot(at: dayIndex)
            let incomingSlot = incoming.slot(at: dayIndex)
            if let localSlot, localSlot.isFilled { return localSlot }
            if let incomingSlot, incomingSlot.isFilled { return incomingSlot }
            return localSlot ?? incomingSlot ?? Slot(dayIndex: dayIndex)
        }
        return merged
    }

    // MARK: -

    private func persist() {
        store.save(group)
    }
}
