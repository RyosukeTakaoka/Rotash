import Foundation

/// 2つの状態を突き合わせる処理。バトン（ファイル手渡し）とサーバー同期の両方で使う。
///
/// 基本方針は「写真を絶対に落とさない」こと。
/// どちらか一方にしか無い写真は必ず残し、同じ枠に両方あるときは先に撮られた方を採用する。
/// 副作用が無いので、そのままテストできる。
enum RotashMerge {

    /// 週の突き合わせ。週途中スタートで枠数が違うこともあるので、両方の曜日をまとめて見る。
    static func merge(local: RotashWeek, remote: RotashWeek) -> RotashWeek {
        var merged = remote
        merged.id = local.id
        merged.firstDayIndex = min(local.firstDayIndex, remote.firstDayIndex)

        let dayIndices = Set(local.dayIndices).union(remote.dayIndices).sorted()
        merged.slots = dayIndices.map { dayIndex in
            mergeSlot(local: local.slot(at: dayIndex),
                      remote: remote.slot(at: dayIndex),
                      dayIndex: dayIndex)
        }
        return merged
    }

    /// photoFilename はその端末の中でしか意味を持たないファイル名なので、
    /// 相手から受け取った枠を採用するときは必ず捨てる。
    /// （持ち込むと「ファイル名はあるのに写真が無い」枠になり、真っ暗な枠として表示されてしまう）
    private static func adopted(_ slot: Slot) -> Slot {
        var adopted = slot
        adopted.photoFilename = nil
        return adopted
    }

    private static func mergeSlot(local: Slot?, remote: Slot?, dayIndex: Int) -> Slot {
        switch (local, remote) {
        case let (local?, remote?):
            // 同じ枠に両方写真があるなら、先に撮られた方をその日の1枚とする。
            if local.isFilled, remote.isFilled {
                let localIsEarlier = (local.capturedAt ?? .distantFuture) <= (remote.capturedAt ?? .distantFuture)
                // 別々の写真なので、負けた側のファイル名も URL も引き継がない。
                return localIsEarlier ? local : adopted(remote)
            }
            if local.isFilled { return local }
            if remote.isFilled { return adopted(remote) }
            // どちらにも写真が無ければ、担当者の決まっている方を優先する。
            return remote.assigneeID != nil ? adopted(remote) : local
        case let (local?, nil):
            return local
        case let (nil, remote?):
            return adopted(remote)
        case (nil, nil):
            return Slot(dayIndex: dayIndex)
        }
    }

    /// グループ全体の突き合わせ。
    /// メンバーはリモートを正とし、自分自身は名前で照合する（端末ごとに UUID が違うため）。
    static func merge(local: RotashGroup, remote: RemoteGroupState) -> RotashGroup {
        var merged = local
        merged.id = remote.id
        merged.name = remote.name

        // メンバー: リモートに自分と同じ名前の人がいればその ID を採用し、いなければ自分を足す。
        var members = remote.members
        let myName = local.me?.name ?? ""
        if let match = members.first(where: { $0.name.caseInsensitiveCompare(myName) == .orderedSame }) {
            merged.myMemberID = match.id
        } else if let me = local.me {
            members.append(me)
        }
        // リモートがまだ知らないローカル側のメンバーも落とさない。
        for member in local.members where !members.contains(where: {
            $0.name.caseInsensitiveCompare(member.name) == .orderedSame
        }) {
            members.append(member)
        }
        merged.members = members

        // 週: 同じ週なら突き合わせ、違う週なら新しい方を今週にして古い方は Memories へ。
        var archive = local.archive
        if remote.currentWeek.startDate == local.currentWeek.startDate {
            merged.currentWeek = merge(local: local.currentWeek, remote: remote.currentWeek)
        } else if remote.currentWeek.startDate > local.currentWeek.startDate {
            if local.currentWeek.filledCount > 0 {
                archive.append(local.currentWeek)
            }
            merged.currentWeek = remote.currentWeek
        } else {
            merged.currentWeek = local.currentWeek
            if remote.currentWeek.filledCount > 0 {
                archive.append(remote.currentWeek)
            }
        }

        // Memories: 同じ週は突き合わせ、片方にしか無い週はそのまま残す。
        for remoteWeek in remote.archive {
            archive.append(remoteWeek)
        }
        merged.archive = consolidate(archive, excluding: merged.currentWeek.startDate)

        return merged
    }

    /// 同じ開始日の週をひとつにまとめ、新しい順に並べる。
    static func consolidate(_ weeks: [RotashWeek], excluding currentStart: Date? = nil) -> [RotashWeek] {
        var byStart: [Date: RotashWeek] = [:]
        for week in weeks {
            if let existing = byStart[week.startDate] {
                byStart[week.startDate] = merge(local: existing, remote: week)
            } else {
                byStart[week.startDate] = week
            }
        }
        if let currentStart { byStart.removeValue(forKey: currentStart) }
        return byStart.values
            .filter { $0.filledCount > 0 }
            .sorted { $0.startDate > $1.startDate }
    }
}

/// サーバー上に置くグループの状態。ローカルの RotashGroup から
/// 端末固有の情報（自分が誰か）を除いたもの。
struct RemoteGroupState: Codable {
    var id: UUID
    var name: String
    var inviteCode: String
    var members: [Member]
    var currentWeek: RotashWeek
    var archive: [RotashWeek]

    init(group: RotashGroup) {
        self.id = group.id
        self.name = group.name
        self.inviteCode = group.inviteCode
        self.members = group.members
        self.currentWeek = Self.shared(group.currentWeek)
        self.archive = group.archive.map(Self.shared)
    }

    /// 端末固有の情報を落として、他の人に渡してよい形にする。
    ///
    /// photoFilename はその端末のローカルキャッシュのファイル名でしかないので、
    /// これを載せると相手側で「写真がある枠」と誤認されてしまう。
    /// 他の人に写真が届く手段は photoURL だけなので、それだけを共有する。
    /// アップロードがまだ済んでいない枠は、相手からは「まだ写真が無い」状態に見える。
    private static func shared(_ week: RotashWeek) -> RotashWeek {
        var shared = week
        for index in shared.slots.indices {
            shared.slots[index].photoFilename = nil
        }
        return shared
    }
}
