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

/// 枠の状態。
/// No Shot は「休み」「欠席」といった管理上の状態ではなく、
/// 「その日には写真がなかった」という作品上の状態として扱う。
enum SlotState: Equatable {
    /// 写真がある
    case photo
    /// その日は写真がないまま終わった
    case noShot
    /// 今日。まだ写真がない
    case today
    /// これから来る日
    case upcoming
}

/// 7 分割のうちの 1 枠。
struct Slot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// 0 = 月曜 ... 6 = 日曜
    var dayIndex: Int
    /// この日の担当者。週の開始時にまとめて決まるが、
    /// その日が来るまでは UI 側で伏せる（誰が次に撮るか分からない状態を保つ）。
    var assigneeID: UUID?
    /// assigneeID が決まった時刻。端末間で担当が競合したときに
    /// 「より新しく決まった方」を採用するための時刻（同期のマージで使う）。
    var assignedAt: Date?
    /// PhotoStore 上のファイル名。この端末にまだ写真が落ちていなければ nil。
    var photoFilename: String?
    /// Cloudinary 上の URL。同期している場合はこちらが本体で、ローカルはキャッシュ。
    var photoURL: String?
    var capturedAt: Date?
    var takenByMemberID: UUID?

    /// 写真がある枠かどうか。
    /// 他の端末で撮られてまだダウンロードしていない状態も「写真がある」として扱う。
    var isFilled: Bool { photoFilename != nil || photoURL != nil }
}

// MARK: - Week (= 1 作品)

/// 1 週間 = 1 つの作品。枠がすべて埋まると完成する。
///
/// カレンダー上の週は常に月曜〜日曜。`startDate` はその週の月曜で、週の同一性もこれで判定する。
/// 週の途中でグループを作った初回だけ `firstDayIndex` が 0 より大きくなり、
/// その日から日曜までの枚数で 1 つの作品になる（例: 金曜開始なら FRI/SAT/SUN の 3 枚）。
/// 翌週からは通常どおり月曜始まりの 7 枚に戻る。
struct RotashWeek: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// その週の月曜 00:00
    var startDate: Date
    /// この週が実際に始まる曜日（0 = 月曜）。通常は 0。
    var firstDayIndex: Int = 0
    var slots: [Slot]

    enum CodingKeys: String, CodingKey {
        case id, startDate, firstDayIndex, slots
    }

    init(id: UUID = UUID(), startDate: Date, firstDayIndex: Int = 0, slots: [Slot]) {
        self.id = id
        self.startDate = startDate
        self.firstDayIndex = firstDayIndex
        self.slots = slots
    }

    /// 既存の保存データ（firstDayIndex を持たない・rotationOffset を持つ形）も読めるようにしておく。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startDate = try container.decode(Date.self, forKey: .startDate)
        firstDayIndex = try container.decodeIfPresent(Int.self, forKey: .firstDayIndex) ?? 0
        slots = try container.decode([Slot].self, forKey: .slots)
    }

    /// 月曜から始まる通常の週。
    static func full(startDate: Date) -> RotashWeek {
        RotashWeek(startDate: startDate,
                   firstDayIndex: 0,
                   slots: (0..<7).map { Slot(dayIndex: $0) })
    }

    /// 週の途中から始まる初回だけの週。
    static func starting(atDayIndex dayIndex: Int, startDate: Date) -> RotashWeek {
        let first = min(max(dayIndex, 0), 6)
        return RotashWeek(startDate: startDate,
                          firstDayIndex: first,
                          slots: (first...6).map { Slot(dayIndex: $0) })
    }

    var dayIndices: [Int] { slots.map(\.dayIndex).sorted() }
    var filledCount: Int { slots.filter(\.isFilled).count }

    /// すべての枠が写真で埋まった、欠けのない状態。
    var isComplete: Bool { !slots.isEmpty && filledCount == slots.count }

    /// 写真が撮られないまま終わった日の数。
    var noShotCount: Int { slots.filter { state(of: $0) == .noShot }.count }

    /// その週の枠がすべて決着した状態（写真か No Shot か）。
    /// 撮られなかった日があっても作品としては成立するので、
    /// 共有できるかどうかはこちらで判断する。
    var isFinished: Bool {
        guard !slots.isEmpty else { return false }
        return slots.allSatisfy { slot in
            let state = state(of: slot)
            return state == .photo || state == .noShot
        }
    }

    /// 枠の状態。写真の有無と日付だけで決まる。
    /// No Shot は別に記録するのではなく「過ぎたのに写真がない日」として導出するので、
    /// 状態遷移の処理を持たずに済み、過去の週でも常に正しくなる。
    func state(of slot: Slot, now: Date = Date()) -> SlotState {
        if slot.isFilled { return .photo }
        let calendar = Calendar.rotash
        let slotDate = calendar.date(byAdding: .day, value: slot.dayIndex, to: startDate) ?? startDate
        if calendar.isDate(slotDate, inSameDayAs: now) { return .today }
        return slotDate < calendar.startOfDay(for: now) ? .noShot : .upcoming
    }


    /// 作品としての初日（通常は月曜、週途中スタートならその日）。
    var displayStartDate: Date {
        Calendar.rotash.date(byAdding: .day, value: firstDayIndex, to: startDate) ?? startDate
    }

    var endDate: Date {
        Calendar.rotash.date(byAdding: .day, value: 6, to: startDate) ?? startDate
    }

    func slot(at dayIndex: Int) -> Slot? {
        slots.first { $0.dayIndex == dayIndex }
    }

    /// 曜日 -> 担当者。担当者の決定履歴として使う（表示用ではない）。
    var assignments: [Int: UUID] {
        var result: [Int: UUID] = [:]
        for slot in slots {
            if let id = slot.assigneeID { result[slot.dayIndex] = id }
        }
        return result
    }

    /// この週の最終日の担当者。次の週の頭で 2 日連続を避けるために見る。
    var lastAssignee: UUID? {
        slots.max(by: { $0.dayIndex < $1.dayIndex })?.assigneeID
    }

    var title: String {
        "\(RotashDateFormat.day.string(from: displayStartDate)) - \(RotashDateFormat.day.string(from: endDate))"
    }
}

// MARK: - Group

/// MVP は 1 グループのみ。掛け持ちは扱わない。
///
/// グループは毎週続く。ユーザーが「新しい週を作る」操作はなく、
/// 月曜になったら currentWeek が自動的に次の週へ切り替わり、前の週は archive に落ちる。
struct RotashGroup: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var inviteCode: String
    var members: [Member]
    var myMemberID: UUID
    var currentWeek: RotashWeek
    /// 過去の作品（Memories）。新しいものが先頭。
    var archive: [RotashWeek] = []

    var me: Member? { members.first { $0.id == myMemberID } }

    /// その日の担当者。週の開始時に決まったものを引くだけ。
    /// 未来の日を伏せるかどうかは表示側の責任なので、ここでは常に本当の担当者を返す。
    func member(forDay dayIndex: Int, in week: RotashWeek) -> Member? {
        guard let id = week.slot(at: dayIndex)?.assigneeID else { return nil }
        return members.first { $0.id == id }
    }

    func isMyDay(_ dayIndex: Int, in week: RotashWeek) -> Bool {
        guard let id = week.slot(at: dayIndex)?.assigneeID else { return false }
        return id == myMemberID
    }

    func member(withID id: UUID) -> Member? {
        members.first { $0.id == id }
    }

    /// 累計の担当回数。次の週の担当者を決めるときの公平性の基準になる。
    var cumulativeAssignmentCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for week in [currentWeek] + archive {
            for slot in week.slots {
                if let id = slot.assigneeID { counts[id, default: 0] += 1 }
            }
        }
        return counts
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

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
