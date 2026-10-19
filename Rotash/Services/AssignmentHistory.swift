import Foundation

/// 担当決め（`AssignmentPlanner`）に渡す「これまで」の記録。
///
/// どちらも、同期で全員に同じものが届く情報（各週の担当・メンバーの入った時刻）だけから計算する。
/// 端末ごとに違う値になると、端末ごとに違う担当表ができてしまうため。
extension RotashGroup {

    /// 担当決めに使う、まだいるメンバーそれぞれの担当回数。
    ///
    /// 単純に数えると、長く続いているグループに入った人は 0 回から始まるので、
    /// 前からいる人に追いつくまで1日おきに番が回り、前からいる人が何日も待たされる
    /// （3人で10週続けたところに4人目が入ると、4人目が4週間の46%の日を担当していた）。
    /// そこで入った人は「入った時点で、前からいた人のうち最も少ない回数」から数え始める。
    /// 抜けて入り直した人は、前の自分の回数とその値の多い方から数える（入り直して一気に番が来ないように）。
    ///
    /// - Parameter today: 今週のどの日までを数えるか（その日を含む）。nil なら今週の全部。
    func effectiveAssignmentCounts(currentWeekThrough today: Int? = nil) -> [UUID: Int] {
        let entries = assignmentEntries(currentWeekThrough: today)

        func count(_ id: UUID, from start: Date?, to end: Date?) -> Int {
            entries.filter { entry in
                guard entry.memberID == id else { return false }
                if let start, entry.date < start { return false }
                if let end, entry.date >= end { return false }
                return true
            }.count
        }

        // 入った時点で前からいた人のうち、最も少ない回数（グループを作った人は 0）。
        // 前からいた人の値が先に決まっているよう、入った順に（作った人が先）決めていく。
        var baselines: [UUID: Int] = [:]
        func effectiveCount(of member: Member, before end: Date?) -> Int {
            guard let joinedAt = member.joinedAt else { return count(member.id, from: nil, to: end) }
            return max(count(member.id, from: nil, to: joinedAt), baselines[member.id] ?? 0)
                + count(member.id, from: joinedAt, to: end)
        }
        let byJoining = activeMembers.sorted { lhs, rhs in
            switch (lhs.joinedAt, rhs.joinedAt) {
            case (nil, nil): return lhs.id.uuidString < rhs.id.uuidString
            case (nil, _): return true
            case (_, nil): return false
            case let (left?, right?): return left == right ? lhs.id.uuidString < rhs.id.uuidString : left < right
            }
        }
        for member in byJoining {
            guard let joinedAt = member.joinedAt else { continue }
            let earlier = byJoining.filter { other in
                other.id != member.id && (other.joinedAt.map { $0 < joinedAt } ?? true)
            }
            let lowest = earlier.map { effectiveCount(of: $0, before: joinedAt) }.min() ?? 0
            baselines[member.id] = lowest
        }

        var result: [UUID: Int] = [:]
        for member in byJoining {
            result[member.id] = effectiveCount(of: member, before: nil)
        }
        return result
    }

    /// まだいるメンバーそれぞれが、最後に番だった日。`week` の月曜を 0 とした日数（前の週ならマイナス）。
    ///
    /// 番がまだ無い人や、最後の番より後に入り直した人は、入った日を最後の番とみなす
    /// （入ってから「人数+1日」以内に最初の番が来る）。
    ///
    /// - Parameters:
    ///   - week: 日数の起点にする週（これから組む週）。
    ///   - dayIndex: この曜日より前の担当だけを見る（組み直す最初の日）。
    func lastTurnDays(for week: RotashWeek, before dayIndex: Int) -> [UUID: Int] {
        let calendar = Calendar.rotash
        let origin = calendar.startOfDay(for: week.startDate)
        func offset(of date: Date) -> Int {
            calendar.dateComponents([.day], from: origin, to: calendar.startOfDay(for: date)).day ?? 0
        }

        var last: [UUID: Int] = [:]
        for weekRecord in [currentWeek] + archive {
            for slot in weekRecord.slots {
                guard let id = slot.assigneeID, let date = weekRecord.date(of: slot) else { continue }
                let day = offset(of: date)
                guard day < dayIndex else { continue }
                last[id] = max(last[id] ?? day, day)
            }
        }

        var result: [UUID: Int] = [:]
        for member in activeMembers {
            var day = last[member.id]
            if let joinedAt = member.joinedAt {
                let joinedDay = min(offset(of: joinedAt), dayIndex - 1)
                if day.map({ joinedDay > $0 }) ?? true { day = joinedDay }
            }
            if let day { result[member.id] = day }
        }
        return result
    }

    /// 番の間隔の上限（番から次の番まで、最大で何日か）。上限をかけない設定なら nil。
    var maxTurnGap: Int? {
        RotashFeatureFlags.turnGapAllowance.map { max(1, activeMembers.count) + $0 }
    }

    /// 今週の、その日まで（その日を含む）に担当だった回数。
    func assignmentsThisWeek(through today: Int) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for slot in currentWeek.slots where slot.dayIndex <= today {
            if let id = slot.assigneeID { counts[id, default: 0] += 1 }
        }
        return counts
    }

    /// 担当の記録を「その日の 0 時」と担当者の組にしたもの。
    private func assignmentEntries(currentWeekThrough today: Int?) -> [(date: Date, memberID: UUID)] {
        var entries: [(date: Date, memberID: UUID)] = []
        for (index, week) in ([currentWeek] + archive).enumerated() {
            for slot in week.slots {
                if index == 0, let today, slot.dayIndex > today { continue }
                guard let id = slot.assigneeID, let date = week.date(of: slot) else { continue }
                entries.append((date: date, memberID: id))
            }
        }
        return entries
    }
}
