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
}
