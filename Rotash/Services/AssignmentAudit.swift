import Foundation

/// 担当表の検査と手当て。
///
/// Rotash は端末ごとにローカルで担当を計算し、あとから同期で突き合わせる。
/// この作りである以上、「一時的に食い違う」ことは原理的に避けられない
/// （参加した瞬間、その端末はまだ他のメンバーを一人も知らない）。
/// 避けなければならないのは **食い違ったまま固定されること** の方で、
/// そのために状態が変わる場所では必ずここを通す。
///
/// やることは2つだけ。
///   1. 今のメンバーに居ない人が担当になっていたら直す
///   2. まだ来ていない日を、いまのメンバーで組み直す（同じ結果なら何もしない）
///
/// **過ぎた日と今日の担当には絶対に触らない。**
/// すでに全員に見えているものをあとから書き換えると、
/// 「昨日の担当が変わっていた」という一番まずい壊れ方になる。
/// 担当が食い違ったまま残るより、そちらの方が体験としては悪い。
enum AssignmentAudit {

    // MARK: - 照合コード

    /// 担当表の照合コード。
    ///
    /// 同じ週で担当が同じなら、どの端末でも必ず同じ6文字になる。
    /// 端末固有のもの（自分が誰か・写真のファイル名）は一切混ぜないので、
    /// 3台で見くらべて揃っていれば「全員が同じ担当表を見ている」と言い切れる。
    /// 揃っていなければ、まだ同期が回りきっていないだけ。
    static func fingerprint(_ week: RotashWeek) -> String {
        var text = "\(Int(week.startDate.timeIntervalSince1970))"
        for slot in week.slots.sorted(by: { $0.dayIndex < $1.dayIndex }) {
            text += "|\(slot.dayIndex):\(slot.assigneeID?.uuidString ?? "-")"
        }

        // 紛らわしい I / O は使わない（1 と l、0 と O の読み違いを防ぐ）。
        let letters = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        var value = RotashHash.fnv1a(text)
        var code = ""
        for _ in 0..<6 {
            code.append(letters[Int(value % UInt64(letters.count))])
            value /= UInt64(letters.count)
        }
        return code
    }

    // MARK: - 手当て

    /// 検査して、直せるところを直したグループを返す。副作用は持たない。
    /// 直すところが無ければ、渡されたものをそのまま返す。
    static func repaired(_ group: RotashGroup, now: Date = Date()) -> RotashGroup {
        var updated = group
        guard !updated.members.isEmpty else { return updated }

        let memberIDs = Set(updated.members.map(\.id))
        let today = Calendar.dayIndex(for: now, weekStart: updated.currentWeek.startDate)

        // 1. 今のメンバーに居ない人が担当になっている枠。
        //    このままだと名前が引けず、端末によって「-」に見えたり見えなかったりする。
        for index in updated.currentWeek.slots.indices {
            let slot = updated.currentWeek.slots[index]
            guard let assignee = slot.assigneeID, !memberIDs.contains(assignee) else { continue }

            if let photographer = slot.takenByMemberID, memberIDs.contains(photographer) {
                // 写真が残っているなら、撮った本人の日だったことにする。
                // 作品としてはもう決着しているので、これが一番実態に近い。
                updated.currentWeek.slots[index].assigneeID = photographer
            } else {
                updated.currentWeek.slots[index].assigneeID = nil
                updated.currentWeek.slots[index].assignedAt = nil
            }
        }

        // 2. まだ来ていない日を、いまのメンバーで組み直す。
        //
        //    ただし自分ひとりしか知らないあいだは、何があっても組み直さない。
        //    参加した直後の端末はまだ誰も知らないので、ここで担当を確定させると
        //    あとから届く本物の担当を「こちらの方が新しい」と押しのけてしまう
        //    （これが「全端末で自分が担当に見える」不具合の元だった）。
        //
        //    メンバーが2人以上いる = 相手の状態を一度は受け取れている、と言い切れる。
        //    参加した端末のメンバー一覧は自分ひとりで始まり、
        //    増えるのは同期かバトンで突き合わせたときだけだからである。
        guard updated.members.count > 1 else { return updated }

        let futureDays = updated.currentWeek.slots
            .filter { $0.dayIndex > today && !$0.isFilled }
            .map(\.dayIndex)
        guard !futureDays.isEmpty else { return updated }

        var history: [UUID: Int] = [:]
        for week in updated.archive {
            for slot in week.slots {
                if let id = slot.assigneeID { history[id, default: 0] += 1 }
            }
        }
        for slot in updated.currentWeek.slots where slot.dayIndex <= today {
            if let id = slot.assigneeID { history[id, default: 0] += 1 }
        }

        let ids = updated.members.map(\.id)
        let planned = WeekPlanner.planned(
            week: updated.currentWeek,
            memberIDs: ids,
            history: history,
            previousWeek: updated.archive.first,
            days: futureDays,
            seed: AssignmentPlanner.seed(groupID: updated.id,
                                         weekStart: updated.currentWeek.startDate,
                                         memberIDs: ids))

        // 結果が今と同じなら書かない。
        // 書くと決定時刻だけが新しくなり、同じ表を持っている他の端末の決定を
        // 意味もなく押しのけてしまう（お互いに押し返し合う堂々巡りになる）。
        let before = futureDays.map { updated.currentWeek.slot(at: $0)?.assigneeID }
        let after = futureDays.map { planned.slot(at: $0)?.assigneeID }
        guard before != after else { return updated }

        updated.currentWeek = planned
        return updated
    }
}
