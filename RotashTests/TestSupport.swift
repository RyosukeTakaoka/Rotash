import Foundation
@testable import Rotash

/// テストで使う、決まった日付と小道具。
enum Fixture {
    /// ある週の月曜 0:00（端末の時刻で）。
    static let weekStart = Calendar.startOfWeek(for: Date(timeIntervalSince1970: 1_790_000_000))

    /// 週の dayIndex 日目の、指定した時刻。
    static func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.rotash
        let dayStart = calendar.date(byAdding: .day, value: day, to: weekStart)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)!
    }

    static func week(_ slots: [Slot]) -> RotashWeek {
        RotashWeek(startDate: weekStart, slots: slots)
    }

    /// 7日すべてを、渡した順のメンバーで埋めた週（決定時刻は週の始まり）。
    static func fullWeek(assignees: [UUID]) -> RotashWeek {
        var week = RotashWeek.full(startDate: weekStart)
        for index in week.slots.indices {
            week.slots[index].assigneeID = assignees[index % assignees.count]
            week.slots[index].assignedAt = weekStart
        }
        return week
    }

    static func photo(day: Int, by member: UUID, at date: Date, url: String = "https://example.com/p.jpg") -> Slot {
        var slot = Slot(dayIndex: day)
        slot.photoURL = url
        slot.capturedAt = date
        slot.takenByMemberID = member
        return slot
    }
}
