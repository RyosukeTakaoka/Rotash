import XCTest
@testable import Rotash

/// 担当の決め方と、入った日の番の渡し方。
final class AssignmentTests: XCTestCase {

    private let members = (0..<3).map { _ in UUID() }

    func testSameSeedGivesTheSamePlanOnEveryDevice() {
        var first = RotashSeededGenerator(seed: 42)
        var second = RotashSeededGenerator(seed: 42)
        let days = Array(0...6)
        let one = AssignmentPlanner.plan(memberIDs: members, dayIndices: days, using: &first)
        let other = AssignmentPlanner.plan(memberIDs: members, dayIndices: days, using: &second)
        XCTAssertEqual(one, other)
    }

    func testThreePeopleShareSevenDaysFairlyWithoutBackToBack() {
        var generator = RotashSeededGenerator(seed: 7)
        let plan = AssignmentPlanner.plan(memberIDs: members, dayIndices: Array(0...6), using: &generator)
        let counts = Dictionary(grouping: plan.values, by: { $0 }).mapValues(\.count).values.sorted()
        XCTAssertEqual(counts, [2, 2, 3])
        for day in 1...6 {
            XCTAssertNotEqual(plan[day], plan[day - 1], "day \(day) repeats the day before")
        }
    }

    // MARK: - 入った日の番

    func testNewcomerGetsTodayWhenTodayIsStillEmpty() {
        let owner = members[0]
        let joinedAt = Fixture.date(day: 2, hour: 10)
        var week = Fixture.fullWeek(assignees: [owner])
        let newcomer = Member(id: members[1], name: "new", joinedAt: joinedAt)

        AssignmentAudit.handOverToday(&week, members: [Member(id: owner, name: "owner"), newcomer],
                                      today: 2, now: Fixture.date(day: 2, hour: 11))
        XCTAssertEqual(week.slot(at: 2)?.assigneeID, newcomer.id)
        XCTAssertEqual(week.slot(at: 2)?.assignedAt, joinedAt)
        // ほかの日には触らない。
        XCTAssertEqual(week.slot(at: 1)?.assigneeID, owner)
        XCTAssertEqual(week.slot(at: 3)?.assigneeID, owner)
    }

    func testTodaysPhotoIsNeverTakenAway() {
        let owner = members[0]
        var week = Fixture.fullWeek(assignees: [owner])
        week.slots[2].photoURL = "taken"
        let newcomer = Member(id: members[1], name: "new", joinedAt: Fixture.date(day: 2, hour: 10))

        AssignmentAudit.handOverToday(&week, members: [Member(id: owner, name: "owner"), newcomer],
                                      today: 2, now: Fixture.date(day: 2, hour: 11))
        XCTAssertEqual(week.slot(at: 2)?.assigneeID, owner)
    }

    func testASecondNewcomerTheSameDayDoesNotTakeTheFirstOnesTurn() {
        let owner = members[0]
        let first = Member(id: members[1], name: "first", joinedAt: Fixture.date(day: 2, hour: 10))
        let second = Member(id: members[2], name: "second", joinedAt: Fixture.date(day: 2, hour: 12))
        var week = Fixture.fullWeek(assignees: [owner])

        // 先に入った人だけを知っている端末が渡したあと、2人目を知った端末がもう一度検査する。
        AssignmentAudit.handOverToday(&week, members: [Member(id: owner, name: "o"), first],
                                      today: 2, now: Fixture.date(day: 2, hour: 11))
        AssignmentAudit.handOverToday(&week, members: [Member(id: owner, name: "o"), first, second],
                                      today: 2, now: Fixture.date(day: 2, hour: 13))
        XCTAssertEqual(week.slot(at: 2)?.assigneeID, first.id)
    }

    func testSomeoneWhoJoinedYesterdayDoesNotTakeToday() {
        let owner = members[0]
        var week = Fixture.fullWeek(assignees: [owner])
        let joinedYesterday = Member(id: members[1], name: "y", joinedAt: Fixture.date(day: 1, hour: 20))

        AssignmentAudit.handOverToday(&week, members: [Member(id: owner, name: "o"), joinedYesterday],
                                      today: 2, now: Fixture.date(day: 2, hour: 9))
        XCTAssertEqual(week.slot(at: 2)?.assigneeID, owner)
    }

    // MARK: - 待つ日数の上限（人数+1日）

    func testNobodyWaitsLongerThanMembersPlusOneDays() {
        // 前の週の日曜が members[0]、土曜が members[1]、金曜が members[2]。3人なので上限は4日。
        let lastTurn = [members[0]: -1, members[1]: -2, members[2]: -3]
        for seed in 0..<300 {
            var generator = RotashSeededGenerator(seed: UInt64(seed))
            let plan = AssignmentPlanner.plan(memberIDs: members, dayIndices: Array(0...6),
                                              previousDayAssignee: members[0],
                                              lastTurn: lastTurn, maxGap: 4, using: &generator)
            for id in members {
                let days = [lastTurn[id]!] + plan.filter { $0.value == id }.map(\.key).sorted()
                for (earlier, later) in zip(days, days.dropFirst()) {
                    XCTAssertLessThanOrEqual(later - earlier, 4, "seed \(seed): waited \(later - earlier) days")
                }
                // 週の終わり（日曜）の時点でも、上限を超えて待っている人はいない。
                XCTAssertLessThanOrEqual(6 - days.last!, 4, "seed \(seed)")
            }
        }
    }

    func testWeekCountsIncludeDaysAlreadyAssigned() {
        // 月火水が members[0], members[1], members[0] で決まっていて、木〜日を組み直す。
        // 週全体では 3/2/2 になる（残りの4日だけで揃えると 3/3/1 などになりうる）。
        let already = [members[0]: 2, members[1]: 1]
        for seed in 0..<200 {
            var generator = RotashSeededGenerator(seed: UInt64(seed))
            let plan = AssignmentPlanner.plan(memberIDs: members, dayIndices: Array(3...6),
                                              previousDayAssignee: members[0],
                                              alreadyThisWeek: already, using: &generator)
            var counts = already
            for id in plan.values { counts[id, default: 0] += 1 }
            XCTAssertEqual(members.map { counts[$0, default: 0] }.sorted(), [2, 2, 3], "seed \(seed)")
        }
    }

    func testOwnerGetsATurnWithinTheLimitAfterAFriendJoins() {
        // 2026-10 に実際に起きた週: 月曜は友達、火曜にオーナーが撮り、同じ火曜に別の友達が入った。
        // それまでの決め方では、オーナーに日曜まで一度も番が来ないことがあった。
        for _ in 0..<60 {
            let owner = UUID(), friend = UUID(), newcomer = UUID()
            var week = RotashWeek.full(startDate: Fixture.weekStart)
            week.slots[0].assigneeID = friend
            week.slots[0].assignedAt = Fixture.weekStart
            week.slots[1] = Fixture.photo(day: 1, by: owner, at: Fixture.date(day: 1, hour: 9))
            week.slots[1].assigneeID = owner
            week.slots[1].assignedAt = Fixture.weekStart
            var group = RotashGroup(name: "G", inviteCode: "ABC234",
                                    members: [Member(id: owner, name: "owner"),
                                              Member(id: friend, name: "friend"),
                                              Member(id: newcomer, name: "new",
                                                     joinedAt: Fixture.date(day: 1, hour: 10))],
                                    myMemberID: owner, currentWeek: week)

            // 火曜に入ったあと、毎朝だれかがアプリを開いて組み直される。
            group = AssignmentAudit.repaired(group, now: Fixture.date(day: 1, hour: 11))
            for day in 2...6 {
                group = AssignmentAudit.repaired(group, now: Fixture.date(day: day, hour: 9))
            }
            let ownerDays = group.currentWeek.slots.filter { $0.assigneeID == owner }.map(\.dayIndex)
            XCTAssertTrue(ownerDays.contains { (2...5).contains($0) },
                          "owner's turns: \(ownerDays) — should come back by Saturday")
        }
    }

    // MARK: - 新しく入った人の回数

    func testNewcomerStartsFromTheLowestCountOfThoseAlreadyThere() {
        let a = members[0], b = members[1], c = members[2]
        let previousStart = Calendar.rotash.date(byAdding: .day, value: -7, to: Fixture.weekStart)!
        var previous = RotashWeek.full(startDate: previousStart)
        for index in previous.slots.indices {
            previous.slots[index].assigneeID = index % 2 == 0 ? a : b   // a が4回、b が3回
        }
        var group = RotashGroup(name: "G", inviteCode: "ABC234",
                                members: [Member(id: a, name: "a"),
                                          Member(id: b, name: "b"),
                                          Member(id: c, name: "c", joinedAt: Fixture.date(day: 0, hour: 9))],
                                myMemberID: a, currentWeek: RotashWeek.full(startDate: Fixture.weekStart))
        group.archive = [previous]

        let counts = group.effectiveAssignmentCounts()
        XCTAssertEqual(counts[a], 4)
        XCTAssertEqual(counts[b], 3)
        // c は 0 回からではなく、入った時点で前からいた人の最小（b の3回）から数える。
        XCTAssertEqual(counts[c], 3)
    }

    func testLastTurnOfSomeoneWithoutATurnIsTheDayTheyJoined() {
        let a = members[0], c = members[2]
        var week = RotashWeek.full(startDate: Fixture.weekStart)
        week.slots[0].assigneeID = a
        let group = RotashGroup(name: "G", inviteCode: "ABC234",
                                members: [Member(id: a, name: "a"),
                                          Member(id: c, name: "c", joinedAt: Fixture.date(day: 2, hour: 15))],
                                myMemberID: a, currentWeek: week)
        let last = group.lastTurnDays(for: week, before: 3)
        XCTAssertEqual(last[a], 0)
        XCTAssertEqual(last[c], 2)
        // 2人なので、番から次の番までは最大3日。
        XCTAssertEqual(group.maxTurnGap, 3)
    }
}
