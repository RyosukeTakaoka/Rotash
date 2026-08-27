import Foundation

/// 担当者の決め方。
///
/// 完全ランダムでも単純ローテーションでもなく、「公平性を保証した上でランダム」にする。
/// 副作用を持たない純粋ロジックなので、そのままテストできる。
///
/// 優先順位:
///   1. 累計担当回数の公平性
///   2. その週の担当回数をできるだけ均等に（人数に応じて 4/3、3/2/2、2/2/2/1 …）
///   3. 同じ人の2日連続を原則避ける
///   4. 前週とまったく同じ並びを避ける
///   5. 上記を満たす候補の中でランダム
///
/// 条件を全部は満たせない場合（例: 1人しかいない）でも必ず割り当てを返す。
/// 決められずに進行不能になるくらいなら、条件を段階的に緩める。
enum AssignmentPlanner {

    static func plan(memberIDs: [UUID],
                     dayIndices: [Int],
                     history: [UUID: Int] = [:],
                     previousPattern: [Int: UUID] = [:],
                     previousDayAssignee: UUID? = nil,
                     firstDayPriority: UUID? = nil) -> [Int: UUID] {
        var generator = SystemRandomNumberGenerator()
        return plan(memberIDs: memberIDs,
                    dayIndices: dayIndices,
                    history: history,
                    previousPattern: previousPattern,
                    previousDayAssignee: previousDayAssignee,
                    firstDayPriority: firstDayPriority,
                    using: &generator)
    }

    /// 乱数を差し替えられる形。テストではここに固定シードの生成器を渡す。
    ///
    /// - Parameter firstDayPriority: 最初の1日を必ずこの人に割り当てる。
    ///   途中参加した人が「参加したのに来週まで何もできない」状態にならないようにするため。
    ///   残りの日は通常どおり全員を対象に公平性ルールで決める。
    static func plan<G: RandomNumberGenerator>(memberIDs: [UUID],
                                               dayIndices: [Int],
                                               history: [UUID: Int] = [:],
                                               previousPattern: [Int: UUID] = [:],
                                               previousDayAssignee: UUID? = nil,
                                               firstDayPriority: UUID? = nil,
                                               using generator: inout G) -> [Int: UUID] {
        guard !memberIDs.isEmpty else { return [:] }
        let days = dayIndices.sorted()
        guard !days.isEmpty else { return [:] }

        // その週の割り当て上限。7日を人数で割り、余りの人数だけ1回多く持つ。
        // 3人なら 3/2/2、4人なら 2/2/2/1 になる。
        let base = days.count / memberIDs.count
        let remainder = days.count % memberIDs.count
        let hasCeil = remainder > 0

        var weekCount: [UUID: Int] = [:]
        var total: [UUID: Int] = [:]
        for id in memberIDs { total[id] = history[id] ?? 0 }

        var membersAtCeil = 0
        var result: [Int: UUID] = [:]
        var previous = previousDayAssignee

        for day in days {
            // 途中参加した人は、最初の1日だけ無条件で優先する。
            if day == days.first,
               let priority = firstDayPriority,
               memberIDs.contains(priority) {
                result[day] = priority
                weekCount[priority] = 1
                if hasCeil && base + 1 == 1 { membersAtCeil += 1 }
                total[priority, default: 0] += 1
                previous = priority
                continue
            }

            // Priority 2: 週の担当回数の上限に達していない人だけを候補にする。
            var candidates = memberIDs.filter { id in
                let count = weekCount[id, default: 0]
                if count < base { return true }
                if hasCeil && count == base && membersAtCeil < remainder { return true }
                return false
            }
            if candidates.isEmpty { candidates = memberIDs }   // 緩和

            // Priority 3: 2日連続を避ける。避けられないなら諦める（1人グループなど）。
            var allowed = candidates.filter { $0 != previous }
            if allowed.isEmpty { allowed = candidates }

            // Priority 1: 累計担当回数が最も少ない人を優先する。
            let minimumTotal = allowed.map { total[$0, default: 0] }.min() ?? 0
            var best = allowed.filter { total[$0, default: 0] == minimumTotal }

            // Priority 4: 前週と同じ曜日に同じ人が来るのを避ける。避けられないなら諦める。
            if let sameDayLastWeek = previousPattern[day] {
                let differing = best.filter { $0 != sameDayLastWeek }
                if !differing.isEmpty { best = differing }
            }

            // Priority 5: 残った候補からランダムに選ぶ。
            let chosen = best.randomElement(using: &generator) ?? candidates[0]

            result[day] = chosen
            let updatedCount = weekCount[chosen, default: 0] + 1
            weekCount[chosen] = updatedCount
            if hasCeil && updatedCount == base + 1 { membersAtCeil += 1 }
            total[chosen, default: 0] += 1
            previous = chosen
        }

        return result
    }
}

/// 週そのものに担当者を書き込む係。AssignmentPlanner を Rotash の型に橋渡しするだけ。
enum WeekPlanner {

    /// - Parameters:
    ///   - days: 割り当て直したい曜日。nil ならその週の全部。
    ///           メンバーが増えたときに「まだ公開していない未来の日」だけ組み替える用途で使う。
    static func planned(week: RotashWeek,
                        memberIDs: [UUID],
                        history: [UUID: Int],
                        previousWeek: RotashWeek?,
                        days: [Int]? = nil,
                        firstDayPriority: UUID? = nil) -> RotashWeek {
        var updated = week
        let targetDays = (days ?? week.dayIndices).sorted()
        guard !memberIDs.isEmpty, !targetDays.isEmpty else { return updated }

        // 連続担当を避けるための「前の日の担当者」。
        // 同じ週の中に前日があればそれを、週の頭なら前週の最終日を見る。
        let previousDayAssignee: UUID?
        if let firstDay = targetDays.first, firstDay > week.firstDayIndex {
            previousDayAssignee = week.slot(at: firstDay - 1)?.assigneeID
        } else {
            previousDayAssignee = previousWeek?.lastAssignee
        }

        let plan = AssignmentPlanner.plan(memberIDs: memberIDs,
                                          dayIndices: targetDays,
                                          history: history,
                                          previousPattern: previousWeek?.assignments ?? [:],
                                          previousDayAssignee: previousDayAssignee,
                                          firstDayPriority: firstDayPriority)

        let decidedAt = Date()
        for (day, memberID) in plan {
            if let index = updated.slots.firstIndex(where: { $0.dayIndex == day }) {
                updated.slots[index].assigneeID = memberID
                updated.slots[index].assignedAt = decidedAt
            }
        }
        return updated
    }
}
