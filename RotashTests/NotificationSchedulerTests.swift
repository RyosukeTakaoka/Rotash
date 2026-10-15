import UserNotifications
import XCTest
@testable import Rotash

/// 通知の予約。夜の1通は「その日の担当の本人だけ・まだ撮っていないときだけ」。
final class NotificationSchedulerTests: XCTestCase {

    private let me = UUID()
    private let friend = UUID()

    private func group(myDays: Set<Int>, filled: Set<Int> = []) -> RotashGroup {
        var week = Fixture.fullWeek(assignees: [friend])
        for index in week.slots.indices {
            let day = week.slots[index].dayIndex
            if myDays.contains(day) { week.slots[index].assigneeID = me }
            if filled.contains(day) { week.slots[index].photoURL = "x" }
        }
        return RotashGroup(name: "G", inviteCode: "ABC234",
                           members: [Member(id: me, name: "me"), Member(id: friend, name: "fr")],
                           myMemberID: me, currentWeek: week)
    }

    private func reminderHours(_ requests: [UNNotificationRequest]) -> [Int] {
        requests.filter { $0.identifier.hasPrefix("rotash.remind.") }
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour }
    }

    func testReminderOnlyOnMyUnfilledDaysAt21() {
        let requests = NotificationScheduler.requests(for: group(myDays: [3, 5], filled: [5]),
                                                      now: Fixture.date(day: 3, hour: 10))
        XCTAssertEqual(reminderHours(requests), [21])
    }

    func testNoReminderAfter21() {
        let requests = NotificationScheduler.requests(for: group(myDays: [3]),
                                                      now: Fixture.date(day: 3, hour: 21, minute: 30))
        XCTAssertTrue(reminderHours(requests).isEmpty)
    }

    func testSundayReminderReplacesTheWeekEndNotice() {
        let requests = NotificationScheduler.requests(for: group(myDays: [6]), now: Fixture.date(day: 6, hour: 10))
        XCTAssertEqual(reminderHours(requests), [21])
        XCTAssertFalse(requests.contains { $0.identifier.hasPrefix("rotash.weekend.") })

        let othersSunday = NotificationScheduler.requests(for: group(myDays: []), now: Fixture.date(day: 6, hour: 10))
        XCTAssertTrue(othersSunday.contains { $0.identifier.hasPrefix("rotash.weekend.") })
    }
}
