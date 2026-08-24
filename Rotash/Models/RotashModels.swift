import Foundation

// MARK: - Member

/// Rotash に参加する一人。MVP ではアカウントを持たず、名前だけで識別する。
struct Member: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
}

// MARK: - Day

enum RotashDay: Int, CaseIterable, Codable {
    case mon = 0, tue, wed, thu, fri, sat, sun

    var label: String {
        switch self {
        case .mon: return "MON"
        case .tue: return "TUE"
        case .wed: return "WED"
        case .thu: return "THU"
        case .fri: return "FRI"
        case .sat: return "SAT"
        case .sun: return "SUN"
        }
    }

    static func label(for index: Int) -> String {
        RotashDay(rawValue: index)?.label ?? "---"
    }
}

// MARK: - Slot

/// 7 分割のうちの 1 枠。
struct Slot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// 0 = 月曜 ... 6 = 日曜
    var dayIndex: Int
    /// PhotoStore 上のファイル名。nil なら未撮影。
    var photoFilename: String?
    var capturedAt: Date?
    var takenByMemberID: UUID?

    var isFilled: Bool { photoFilename != nil }
}

// MARK: - Week (= 1 作品)

/// 1 週間 = 1 つの作品。7 枚そろって完成する。
struct RotashWeek: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// その週の月曜 00:00
    var startDate: Date
    /// 週をまたいでも当番が一巡し続けるためのオフセット
    var rotationOffset: Int
    var slots: [Slot]

    static func empty(startDate: Date, rotationOffset: Int) -> RotashWeek {
        RotashWeek(startDate: startDate,
                   rotationOffset: rotationOffset,
                   slots: (0..<7).map { Slot(dayIndex: $0) })
    }

    var filledCount: Int { slots.filter(\.isFilled).count }
    var isComplete: Bool { filledCount == 7 }

    var endDate: Date {
        Calendar.rotash.date(byAdding: .day, value: 6, to: startDate) ?? startDate
    }

    func slot(at dayIndex: Int) -> Slot? {
        slots.first { $0.dayIndex == dayIndex }
    }

    var title: String {
        "\(RotashDateFormat.day.string(from: startDate)) - \(RotashDateFormat.day.string(from: endDate))"
    }
}

// MARK: - Group

/// MVP は 1 グループのみ。掛け持ちは扱わない。
struct RotashGroup: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var inviteCode: String
    /// 配列の順番がそのまま当番の順番になる。
    var members: [Member]
    var myMemberID: UUID
    var currentWeek: RotashWeek
    /// 過去の作品（Memories）。新しいものが先頭。
    var archive: [RotashWeek] = []

    var me: Member? { members.first { $0.id == myMemberID } }

    /// その日の担当者。3 人なら 月A 火B 水C 木A ... と一巡し続ける。
    func member(forDay dayIndex: Int, in week: RotashWeek) -> Member? {
        guard !members.isEmpty else { return nil }
        let index = (week.rotationOffset + dayIndex) % members.count
        return members[index]
    }

    func isMyDay(_ dayIndex: Int, in week: RotashWeek) -> Bool {
        member(forDay: dayIndex, in: week)?.id == myMemberID
    }
}

// MARK: - Calendar / Format helpers

extension Calendar {
    /// 週の始まりは月曜。
    static var rotash: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }

    static func startOfWeek(for date: Date = Date()) -> Date {
        let calendar = Calendar.rotash
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval.start
        }
        return calendar.startOfDay(for: date)
    }

    /// 今日がその週の何日目か（0 = 月曜）。
    static func dayIndex(for date: Date = Date(), weekStart: Date? = nil) -> Int {
        let calendar = Calendar.rotash
        let start = weekStart ?? startOfWeek(for: date)
        let days = calendar.dateComponents([.day],
                                           from: start,
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return min(max(days, 0), 6)
    }
}

enum RotashDateFormat {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
