import SwiftUI
import UIKit

/// 縦向き。Rotash の入口。管理画面ではないので、ここに置くのは
/// グループ名 / 招待コード / 今日の担当者 / Memories / 設定 だけ。
/// 今週の7分割そのもの（進行中の作品）はここでは絶対に見せない。
/// 横にした瞬間に「THIS WEEK」が現れることが Rotash 独自の体験になる。
struct PortraitHomeView: View {

    @EnvironmentObject private var app: AppViewModel

    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let group = app.group {
                        groupBlock(group)
                        memoriesBlock(group)
                    } else {
                        onboarding
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            // 引っぱって更新する処理は、画面が描き直されると途中で取り消される（「キャンセルしました」になる）。
            // 同期そのものは別の仕事として走らせ、ここではその終わりを待つだけにする。
            .refreshable { await Task { await app.sync(showingError: true) }.value }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RotashWeek.self) { week in
                MemoryDetailView(week: week)
            }
        }
        .tint(Palette.text)
        .sheet(item: $app.activeSheet) { sheet in
            Group {
                switch sheet {
                case .create: CreateRotashView()
                case .join: JoinRotashView()
                case .settings: SettingsView()
                }
            }
            .environmentObject(app)
            .interactiveDismissDisabled()
        }
    }

    // MARK: - Blocks

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("ROTASH")
                    .font(Typo.wordmark(28))
                    .tracking(10)
                    .foregroundStyle(Palette.text)
                Spacer()
                Button("SETTINGS") { app.activeSheet = .settings }
                    .font(Typo.label(9, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Palette.faint)
            }
            .padding(.top, 28)
            .padding(.bottom, 22)
            HairLine()
        }
        .padding(.horizontal, 24)
    }

    private func groupBlock(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            groupSwitcher(group)

            // 招待で送るのは6桁のコードではなく、いまの作品そのもの。
            // 受け取った側は、見ただけで何のアプリか分かる。
            InviteShareButton {
                HStack(spacing: 10) {
                    Text("INVITE").rotashLabel(9, color: Palette.faint, tracking: 2)
                    Text(group.inviteCode)
                        .font(Typo.label(15, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(Palette.text)
                    Text("SEND").rotashLabel(8, color: Palette.live, tracking: 1.6)
                }
            }

            // 対面でそのまま伝えたいときのために、コピーも残しておく。
            Button {
                UIPasteboard.general.string = group.inviteCode
                copied = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Text(copied ? "コードをコピーしました" : "コードをコピー")
                    .rotashLabel(9, color: Palette.faint, tracking: 0.8)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                if group.currentWeek.isFinished {
                    Text("今週の作品ができました")
                        .rotashLabel(11, color: Palette.text, tracking: 0.6)
                } else {
                    HStack(spacing: 8) {
                        Text("今日の担当").rotashLabel(9, color: Palette.faint, tracking: 1.6)
                        Text(app.revealedAssignee(forDay: app.todayIndex)?.name.uppercased() ?? "-")
                            .rotashLabel(12, color: app.isMyDay(app.todayIndex) ? Palette.live : Palette.text, tracking: 0.6)
                    }
                }
                Text("→ 横にして見る")
                    .rotashLabel(9, color: Palette.faint, tracking: 1.2)

                membersRow(group)
                    .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 30)
    }

    /// メンバー。丸は、その人が最後に撮った裏の写真（たいてい本人の顔）。撮るたびに替わる。
    /// まだ撮っていない人は頭文字。最後に招待の丸を置く。
    private func membersRow(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("メンバー").rotashLabel(9, color: Palette.faint, tracking: 1.6)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(group.activeMembers) { member in
                        VStack(spacing: 6) {
                            memberIcon(member, in: group)
                            Text(member.name.uppercased())
                                .rotashLabel(8, color: member.id == group.myMemberID ? Palette.live : Palette.dim,
                                             tracking: 0.6)
                                .lineLimit(1)
                                .frame(maxWidth: 56)
                        }
                    }
                    InviteShareButton {
                        VStack(spacing: 6) {
                            Circle()
                                .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .frame(width: 48, height: 48)
                                .overlay(Text("+").rotashLabel(16, color: Palette.dim, tracking: 0))
                            Text("招待する")
                                .rotashLabel(8, color: Palette.faint, tracking: 0.6)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func memberIcon(_ member: Member, in group: RotashGroup) -> some View {
        Group {
            if let slot = group.latestReverseSlot(of: member.id) {
                PhotoImageView(reverseOf: slot, maxPixel: 120)
            } else {
                ZStack {
                    Palette.surface
                    Text(String(member.name.prefix(1)).uppercased())
                        .rotashLabel(15, color: Palette.text, tracking: 0)
                }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
    }

    /// グループ名。押すと、掛け持ちしているグループの切り替えと、新しく作る・参加するが出る。
    private func groupSwitcher(_ group: RotashGroup) -> some View {
        Menu {
            Section {
                ForEach(app.groups) { item in
                    Button {
                        app.switchGroup(to: item.id)
                    } label: {
                        if item.id == group.id {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
            }
            Section {
                Button { app.activeSheet = .create } label: {
                    Label("新しいグループをつくる", systemImage: "plus")
                }
                Button {
                    // 前にリンクから開いたときのコードが残っていると、入力できない画面になるので消す。
                    app.pendingJoinCode = nil
                    app.activeSheet = .join
                } label: {
                    Label("招待コードで参加", systemImage: "person.badge.plus")
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(group.name.uppercased())
                    .font(Typo.title(20))
                    .tracking(2)
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.dim)
                if app.groups.count > 1 {
                    Text("\(app.groups.count)")
                        .rotashLabel(9, color: Palette.faint, tracking: 0.6)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func memoriesBlock(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HairLine()
            HStack {
                Text("MEMORIES").rotashLabel(10, tracking: 3)
                Spacer()
                Text("\(group.archive.count)").rotashLabel(10, color: Palette.faint)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)

            if group.archive.isEmpty {
                Text("完成した作品はまだありません。")
                    .rotashLabel(10, color: Palette.faint, tracking: 0.4)
                    .padding(.bottom, 24)
            } else {
                // いちばん新しい作品だけを大きく見せ、それより前の週は細い帯で積み重ねる。
                //
                // 続いていることは「項目数」ではなく「厚み」として見せる（帯を密着させる）。
                // 連続週数のような数字は出さない。数字は途切れた瞬間にゼロへ戻り、
                // 7人のうち誰か1人がコケるだけで壊れる（毎週およそ3割）。
                // 壊れたときに「お前のせいで切れた」が起きると、共同制作が相互監視に変わる。
                // 積み上がる一方で減らないものだけを、継続の報酬にする。
                if let latest = group.archive.first {
                    NavigationLink(value: latest) {
                        latestCard(latest)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 18)
                }

                let older = Array(group.archive.dropFirst())
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
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 24)
    }

    /// いちばん新しい作品。横画面と同じく7つの枠を横に並べて大きく出し、その下に名前と日付を置く。
    private func latestCard(_ week: RotashWeek) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 横画面で見る作品と同じ形（1枠の縦横比をそろえる）。
            WeekThumbnailStrip(week: week, height: nil)
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
            WeekThumbnailStrip(week: week, height: nil)
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

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("友達と1週間かけて、\n7枚で1つの作品をつくる。")
                .font(Typo.title(18))
                .foregroundStyle(Palette.text)
                .lineSpacing(8)
                .padding(.top, 30)
                .padding(.bottom, 8)

            Text("撮るのは1日にひとりだけ。\n見るのはいつでも全員。")
                .rotashLabel(11, color: Palette.dim, tracking: 0.4)
                .lineSpacing(6)
                .padding(.bottom, 26)

            Button("ROTASH をつくる") { app.activeSheet = .create }
                .buttonStyle(RotashButtonStyle(filled: true))
            Button("招待コードで参加") { app.activeSheet = .join }
                .buttonStyle(RotashButtonStyle())
        }
        .padding(.horizontal, 24)
    }
}
