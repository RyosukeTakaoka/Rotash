import Foundation

/// 種を渡すと、どの端末で回しても同じ並びを返す乱数生成器（SplitMix64）。
///
/// 担当決めに `SystemRandomNumberGenerator` を使うと、同じメンバー・同じ週でも
/// 端末ごとに違う並びが出る。各端末が「自分の考えた並び」を持ったまま同期を待つので、
/// そのあいだ全員が「今日は自分の担当だ」と思い込み、同じ日を2人で撮ってしまう。
/// 担当は「みんなで1つ」でなければならないので、計算そのものを端末非依存にする。
struct RotashSeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 担当者の決め方。
///
/// 完全ランダムでも単純ローテーションでもなく、「公平性を保証した上でランダム」にする。
/// 副作用を持たない純粋ロジックなので、そのままテストできる。
///
/// 優先順位:
///   1. その週の担当回数をできるだけ均等に（人数に応じて 4/3、3/2/2、2/2/2/1 …）。
///      今週すでに過ぎた日の担当も数に入れる（`alreadyThisWeek`）
///   2. 誰も「人数+1日」を超えて待たせない（`maxGap`）。守れない日は、いちばん長く待っている人
///   3. 同じ人の2日連続を原則避ける
///   4. 累計担当回数の公平性
///   5. 前週とまったく同じ並びを避ける
///   6. 上記を満たす候補の中でランダム
///
/// 条件を全部は満たせない場合（例: 1人しかいない）でも必ず割り当てを返す。
/// 決められずに進行不能になるくらいなら、条件を段階的に緩める。
///
/// 2 を足したのは 2026-10-19。それまでは待つ日数に上限が無く、
/// 累計が多い人が「毎日の組み直し」（`AssignmentAudit`）のたびに後ろへ押され、
/// 3人のグループで火曜のあと日曜まで一度も番が来ない、ということが実際に起きた。
/// シミュレーション（`tools/assignment-sim.py`）で確かめた結果は `docs/ASSIGNMENT_RULES.md`。
enum AssignmentPlanner {

    static func plan(memberIDs: [UUID],
                     dayIndices: [Int],
                     history: [UUID: Int] = [:],
                     previousPattern: [Int: UUID] = [:],
                     previousDayAssignee: UUID? = nil,
                     alreadyThisWeek: [UUID: Int] = [:],
                     lastTurn: [UUID: Int] = [:],
                     maxGap: Int? = nil) -> [Int: UUID] {
        var generator = SystemRandomNumberGenerator()
        return plan(memberIDs: memberIDs,
                    dayIndices: dayIndices,
                    history: history,
                    previousPattern: previousPattern,
                    previousDayAssignee: previousDayAssignee,
                    alreadyThisWeek: alreadyThisWeek,
                    lastTurn: lastTurn,
                    maxGap: maxGap,
                    using: &generator)
    }

    /// 乱数を差し替えられる形。テストではここに固定シードの生成器を渡す。
    ///
    /// 以前は「途中参加した人に最初の1日を無条件で渡す」指定を持っていたが、外した。
    /// 同じ日に二人が参加すると、後から入った人が同じ日を無条件に奪い、
    /// **先に参加した人の当番が今週から丸ごと消える**という壊れ方をしていた
    /// （＝この指定が防ごうとしていた「参加したのに何もできない」状態そのもの）。
    ///
    /// 外しても目的は達せられる。Priority 1 が累計担当回数の少ない人を優先するので、
    /// 累計 0 回の新しい人が、放っておいても最初の空き日に入る。
    /// 無条件の指定と違って「誰が引き金を引いたか」に結果が左右されないため、
    /// どの端末で計算しても同じ表になる。
    /// - Parameters:
    ///   - alreadyThisWeek: 今週の、ここで組まない日（過ぎた日と今日）に、すでに担当だった回数。
    ///     週の途中で組み直すときに渡す。渡さないと、残りの日だけで回数を揃えてしまい、
    ///     週全体では 3/2/2 のはずが 3/3/1 になることがある。
    ///   - lastTurn: それぞれが最後に番だった日。この週の月曜を 0 とした日数（前の週ならマイナス）。
    ///     まだ番が無い人は、入った日を入れておく。ここに無い人には待つ日数の上限をかけない。
    ///   - maxGap: 番から次の番まで、最大で何日にするか（ふつうは人数+1）。nil なら上限なし。
    static func plan<G: RandomNumberGenerator>(memberIDs: [UUID],
                                               dayIndices: [Int],
                                               history: [UUID: Int] = [:],
                                               previousPattern: [Int: UUID] = [:],
                                               previousDayAssignee: UUID? = nil,
                                               alreadyThisWeek: [UUID: Int] = [:],
                                               lastTurn: [UUID: Int] = [:],
                                               maxGap: Int? = nil,
                                               using generator: inout G) -> [Int: UUID] {
        guard !memberIDs.isEmpty else { return [:] }
        let days = dayIndices.sorted()
        guard !days.isEmpty else { return [:] }

        // その週の割り当て上限。週の日数を人数で割り、余りの人数だけ1回多く持つ。
        // 3人なら 3/2/2、4人なら 2/2/2/1 になる。今週すでに担当だった日も数に入れる。
        var weekCount: [UUID: Int] = [:]
        for id in memberIDs { weekCount[id] = alreadyThisWeek[id] ?? 0 }
        let weekDays = days.count + weekCount.values.reduce(0, +)
        let base = weekDays / memberIDs.count
        let remainder = weekDays % memberIDs.count
        let hasCeil = remainder > 0
        var membersAtCeil = memberIDs.filter { weekCount[$0, default: 0] > base }.count

        var total: [UUID: Int] = [:]
        for id in memberIDs { total[id] = history[id] ?? 0 }

        var lastSeen = lastTurn
        var result: [Int: UUID] = [:]
        var previous = previousDayAssignee

        /// その人を `day` の担当にしても、ほかの全員が `maxGap` 日以内に番を迎えられるか。
        ///
        /// 期限（最後の番 + maxGap）が今日か、もう過ぎている人がほかにいれば、その人を選ぶしかない。
        /// それ以外は「k 日のうちに期限が来る人数が k 人以下」なら、期限の早い順に1日1人ずつ割り当てられる。
        func keepsEveryoneWithinGap(_ candidate: UUID, on day: Int) -> Bool {
            guard let maxGap else { return true }
            var deadlines: [Int] = []
            for id in memberIDs where id != candidate {
                guard let last = lastSeen[id] else { continue }
                let deadline = last + maxGap
                if deadline <= day { return false }
                deadlines.append(deadline)
            }
            for ahead in 1...(maxGap + 1) where deadlines.filter({ $0 <= day + ahead }).count > ahead {
                return false
            }
            return true
        }

        for day in days {
            // Priority 1: 週の担当回数の上限に達していない人だけを候補にする。
            var candidates = memberIDs.filter { id in
                let count = weekCount[id, default: 0]
                if count < base { return true }
                if hasCeil && count == base && membersAtCeil < remainder { return true }
                return false
            }
            if candidates.isEmpty { candidates = memberIDs }   // 緩和

            // Priority 2: 待つ日数の上限を守れる人だけにする。
            // 回数の上限の中で守れなければ回数の上限を緩め、それでも守れなければ（人が抜けた直後など）
            // いちばん長く待っている人にする（同じならメンバーの並び順。どの端末でも同じ人になる）。
            if maxGap != nil {
                let within = candidates.filter { keepsEveryoneWithinGap($0, on: day) }
                if !within.isEmpty {
                    candidates = within
                } else {
                    let anyone = memberIDs.filter { keepsEveryoneWithinGap($0, on: day) }
                    if !anyone.isEmpty {
                        candidates = anyone
                    } else if let longest = memberIDs
                                .filter({ lastSeen[$0] != nil })
                                .min(by: { lastSeen[$0, default: 0] < lastSeen[$1, default: 0] }) {
                        candidates = [longest]
                    }
                }
            }

            // Priority 3: 2日連続を避ける。避けられないなら諦める（1人グループなど）。
            var allowed = candidates.filter { $0 != previous }
            if allowed.isEmpty { allowed = candidates }

            // Priority 4: 累計担当回数が最も少ない人を優先する。
            let minimumTotal = allowed.map { total[$0, default: 0] }.min() ?? 0
            var best = allowed.filter { total[$0, default: 0] == minimumTotal }

            // Priority 5: 前週と同じ曜日に同じ人が来るのを避ける。避けられないなら諦める。
            if let sameDayLastWeek = previousPattern[day] {
                let differing = best.filter { $0 != sameDayLastWeek }
                if !differing.isEmpty { best = differing }
            }

            // Priority 6: 残った候補からランダムに選ぶ。
            let chosen = best.randomElement(using: &generator) ?? candidates[0]

            result[day] = chosen
            let updatedCount = weekCount[chosen, default: 0] + 1
            weekCount[chosen] = updatedCount
            if hasCeil && updatedCount == base + 1 { membersAtCeil += 1 }
            total[chosen, default: 0] += 1
            lastSeen[chosen] = day
            previous = chosen
        }

        return result
    }

    /// 担当決めの種。
    ///
    /// 同じグループ・同じ週・同じメンバーであれば、どの端末で作っても必ず同じ値になる。
    /// これを `RotashSeededGenerator` に渡すことで、担当の決定が端末に依存しなくなる。
    ///
    /// - Parameter salt: 同じ週の中で別の計算をしたいときの区別（途中参加の組み替えなど）。
    static func seed(groupID: UUID,
                     weekStart: Date,
                     memberIDs: [UUID],
                     salt: String = "") -> UInt64 {
        var text = groupID.uuidString
        text += "|\(Int(weekStart.timeIntervalSince1970))"
        for id in memberIDs.map(\.uuidString).sorted() { text += "|\(id)" }
        if !salt.isEmpty { text += "|\(salt)" }
        return RotashHash.fnv1a(text)
    }
}

/// 端末をまたいで同じ値になる、軽いハッシュ。
/// 担当決めの種と、担当表の照合コードで使う。暗号用途ではない。
enum RotashHash {
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

/// 週そのものに担当者を書き込む係。AssignmentPlanner を Rotash の型に橋渡しするだけ。
enum WeekPlanner {

    /// - Parameters:
    ///   - days: 割り当て直したい曜日。nil ならその週の全部。
    ///           メンバーが増えたときに「まだ公開していない未来の日」だけ組み替える用途で使う。
    ///   - seed: 渡すと、同じ入力からは必ず同じ担当表が出る（端末をまたいでも一致する）。
    ///           nil なら従来どおり毎回ランダム。
    ///   - alreadyThisWeek / lastTurn / maxGap: `AssignmentPlanner.plan` にそのまま渡す。
    ///   - decidedAt: 担当が決まった時刻として記録する値。既定は「いま」。
    ///           週送りのように **各端末がそれぞれ勝手に走らせる計算** では、
    ///           ここに端末共通の値（その週の開始日）を渡す。
    ///           そうすると同じ計算をした端末どうしが同着になり、
    ///           マージの同着処理で必ず同じ側が選ばれる。
    ///           「いま」を入れると、あとから走らせた端末が常に勝ってしまい、
    ///           先に決まっていた担当を意味もなく押しのけることになる。
    static func planned(week: RotashWeek,
                        memberIDs: [UUID],
                        history: [UUID: Int],
                        previousWeek: RotashWeek?,
                        days: [Int]? = nil,
                        seed: UInt64? = nil,
                        alreadyThisWeek: [UUID: Int] = [:],
                        lastTurn: [UUID: Int] = [:],
                        maxGap: Int? = nil,
                        decidedAt: Date = Date()) -> RotashWeek {
        var updated = week
        let targetDays = (days ?? week.dayIndices).sorted()

        // メンバーの並び順は端末ごとに違う（同期のマージで足された順が違うため）。
        // 並び順で結果が変わってしまうと種を揃えても一致しないので、必ず整列してから計算する。
        let orderedIDs = memberIDs.sorted { $0.uuidString < $1.uuidString }
        guard !orderedIDs.isEmpty, !targetDays.isEmpty else { return updated }

        // 連続担当を避けるための「前の日の担当者」。
        // 同じ週の中に前日があればそれを、週の頭なら前週の最終日を見る。
        let previousDayAssignee: UUID?
        if let firstDay = targetDays.first, firstDay > week.firstDayIndex {
            previousDayAssignee = week.slot(at: firstDay - 1)?.assigneeID
        } else {
            previousDayAssignee = previousWeek?.lastAssignee
        }

        let plan: [Int: UUID]
        if let seed {
            var generator = RotashSeededGenerator(seed: seed)
            plan = AssignmentPlanner.plan(memberIDs: orderedIDs,
                                          dayIndices: targetDays,
                                          history: history,
                                          previousPattern: previousWeek?.assignments ?? [:],
                                          previousDayAssignee: previousDayAssignee,
                                          alreadyThisWeek: alreadyThisWeek,
                                          lastTurn: lastTurn,
                                          maxGap: maxGap,
                                          using: &generator)
        } else {
            plan = AssignmentPlanner.plan(memberIDs: orderedIDs,
                                          dayIndices: targetDays,
                                          history: history,
                                          previousPattern: previousWeek?.assignments ?? [:],
                                          previousDayAssignee: previousDayAssignee,
                                          alreadyThisWeek: alreadyThisWeek,
                                          lastTurn: lastTurn,
                                          maxGap: maxGap)
        }

        for (day, memberID) in plan {
            if let index = updated.slots.firstIndex(where: { $0.dayIndex == day }) {
                updated.slots[index].assigneeID = memberID
                updated.slots[index].assignedAt = decidedAt
            }
        }
        return updated
    }
}
