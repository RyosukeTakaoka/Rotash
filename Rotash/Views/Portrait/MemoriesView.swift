import SwiftUI

/// Memories（これまでの作品）の画面。縦のホームの「MEMORIES」から開く。
///
/// 作品は週ごとに増え続けるので、全部をホームに並べると、ホームがどこまでも長くなる。
/// ホームには先週の作品だけを残し（`PortraitHomeView`）、全部はここに置く（2026-10-15）。
///
/// いちばん新しい作品だけを大きく見せ、それより前の週は細い帯で積み重ねる。
/// 続いていることは「項目数」ではなく「厚み」として見せる（帯を密着させる）。
/// 連続週数のような数字は出さない。数字は途切れた瞬間にゼロへ戻り、
/// 7人のうち誰か1人がコケるだけで壊れる（毎週およそ3割）。
/// 壊れたときに「お前のせいで切れた」が起きると、共同制作が相互監視に変わる。
/// 積み上がる一方で減らないものだけを、継続の報酬にする。
struct MemoriesView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    if let group = app.group {
                        content(group)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("← BACK") { dismiss() }
                .font(Typo.label(10, weight: .medium))
                .tracking(2)
                .foregroundStyle(Palette.dim)
                .padding(.top, 22)
                .padding(.bottom, 20)
            HStack(alignment: .firstTextBaseline) {
                Text("MEMORIES").rotashLabel(12, color: Palette.text, tracking: 3)
                Spacer()
                if let group = app.group {
                    Text(group.name.uppercased())
                        .rotashLabel(9, color: Palette.faint, tracking: 1.2)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 18)
            HairLine()
                .padding(.bottom, 22)
        }
    }

    @ViewBuilder
    private func content(_ group: RotashGroup) -> some View {
        if group.memories.isEmpty {
            Text("完成した作品はまだありません。")
                .rotashLabel(10, color: Palette.faint, tracking: 0.4)
        } else {
            if let latest = group.memories.first {
                NavigationLink(value: latest) {
                    latestCard(latest)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }

            let older = Array(group.memories.dropFirst())
            if !older.isEmpty {
                HairLine()
                    .padding(.bottom, 18)
                // それより前の週は、少し小さく・少し薄く積む。右に日付だけ添える。
                // 月ごとに区切り、年が変わるところには年を出す（積み重なった厚みが、時間として読めるように）。
                let sections = Self.monthSections(older)
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        VStack(alignment: .leading, spacing: 12) {
                            if index == 0 || sections[index - 1].year != section.year {
                                Text(String(section.year))
                                    .font(Typo.title(16))
                                    .tracking(2)
                                    .foregroundStyle(Palette.text)
                            }
                            Text(Self.monthFormatter.string(from: section.start))
                                .rotashLabel(9, color: Palette.dim, tracking: 1.2)
                            ForEach(section.weeks) { week in
                                NavigationLink(value: week) {
                                    olderRow(week)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, 22)
            }

            Text("タップすると、その週を見られます。")
                .rotashLabel(9, color: Palette.faint, tracking: 0.4)
        }
    }

    /// いちばん新しい作品。横画面と同じく7つの枠を横に並べて大きく出し、その下に名前と日付を置く。
    private func latestCard(_ week: RotashWeek) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 横画面で見る作品と同じ形（1枠の縦横比をそろえる）。
            WeekThumbnailStrip(week: week, height: nil, hides: { app.isHidden($0) })
                .aspectRatio(WorkShape.stripAspect, contentMode: .fit)
                .padding(.bottom, 16)
            if let title = week.title, !title.isEmpty {
                Text(title)
                    .font(Typo.title(22))
                    .tracking(0.5)
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .padding(.bottom, 8)
            }
            Text(week.dateRange)
                .rotashLabel(11, color: Palette.dim, tracking: 1.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// 同じ月の週をまとめたもの（新しい順のまま）。
    private struct MonthSection: Identifiable {
        let id: String
        let year: Int
        let start: Date
        var weeks: [RotashWeek]
    }

    /// 週を、作品の初日がある月ごとに区切る。並びは渡された順（新しい順）のまま。
    private static func monthSections(_ weeks: [RotashWeek]) -> [MonthSection] {
        let calendar = Calendar.rotash
        var sections: [MonthSection] = []
        for week in weeks {
            let parts = calendar.dateComponents([.year, .month], from: week.displayStartDate)
            let id = "\(parts.year ?? 0)-\(parts.month ?? 0)"
            if sections.last?.id == id {
                sections[sections.count - 1].weeks.append(week)
            } else {
                sections.append(MonthSection(id: id, year: parts.year ?? 0,
                                             start: week.displayStartDate, weeks: [week]))
            }
        }
        return sections
    }

    /// 月の名前（端末の言語で「10月」「October」「10월」）。
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }()

    /// 前の週の1行。7分割を小さく、右に日付（始まりと終わりの2行）。
    private func olderRow(_ week: RotashWeek) -> some View {
        HStack(alignment: .center, spacing: 14) {
            WeekThumbnailStrip(week: week, height: nil, hides: { app.isHidden($0) })
                .aspectRatio(WorkShape.stripAspect, contentMode: .fit)
                .opacity(0.85)
            VStack(alignment: .leading, spacing: 4) {
                Text(RotashDateFormat.day.string(from: week.displayStartDate))
                    .rotashLabel(9, color: Palette.faint, tracking: 0.6)
                Text("- " + RotashDateFormat.day.string(from: week.endDate))
                    .rotashLabel(9, color: Palette.faint, tracking: 0.6)
            }
            .fixedSize()
        }
        .contentShape(Rectangle())
    }
}
