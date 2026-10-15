import SwiftUI
import UIKit

/// 縦向き。Rotash の入口。管理画面ではないので、ここに置くのは
/// グループ名 / 招待コード / 今日の1マス / メンバー / Memories / 設定 だけ。
/// 今週の7分割そのもの（進行中の作品）はここでは見せない。見せるのは今日の1マスだけ（`TodayCard`）。
/// メンバーの丸は、今日の1マスの左右に縦に並べる（1画面に収めるため。2026-10-15）。
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
                }

                // 今日の1マス（縦は「1日」、横は「1週間」）と、その左右にメンバー。
                todayWithMembers(group)
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.5 }
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 30)
    }

    /// 今日の1マスと、その左右に縦に並べたメンバー。
    ///
    /// 今日の1マスは7分割の1枠と同じ細長い形なので、縦の画面では左右が大きく空く。
    /// そこにメンバーを左右に振り分けて並べ、下にあったメンバーの列をなくす（縦のホームを1画面に収める）。
    /// 並びは左・右・左・右…の順。最後に招待の丸（7人そろったら出さない）。
    private func todayWithMembers(_ group: RotashGroup) -> some View {
        GeometryReader { geometry in
            let cardWidth = min(TodayCard.naturalWidth(forHeight: geometry.size.height), geometry.size.width * 0.6)
            let sideWidth = max((geometry.size.width - cardWidth) / 2, 0)
            let items = Self.memberItems(group)
            let left = items.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
            let right = items.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
            HStack(spacing: 0) {
                memberColumn(left, in: group, width: sideWidth)
                TodayCard(week: group.currentWeek,
                          hides: { app.isHidden($0) },
                          todayIndex: app.todayIndex,
                          assigneeName: app.revealedAssignee(forDay: app.todayIndex)?.name,
                          isMine: app.isMyDay(app.todayIndex),
                          showsRotateHint: !app.hasSeenLandscape)
                    .frame(width: cardWidth)
                memberColumn(right, in: group, width: sideWidth)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    /// 左右の列に並べるもの（メンバーと、最後に招待）。
    private enum MemberItem: Identifiable {
        case member(Member)
        case invite

        var id: String {
            switch self {
            case let .member(member): return member.id.uuidString
            case .invite: return "invite"
            }
        }
    }

    private static func memberItems(_ group: RotashGroup) -> [MemberItem] {
        var items = group.activeMembers.map { MemberItem.member($0) }
        if group.activeMembers.count < RotashGroup.capacity { items.append(.invite) }
        return items
    }

    /// 片側の列。丸の大きさは列の幅に合わせる（小さい iPhone でもはみ出さないように）。
    private func memberColumn(_ items: [MemberItem], in group: RotashGroup, width: CGFloat) -> some View {
        let size = max(min(44, width - 16), 28)
        return VStack(spacing: 14) {
            ForEach(items) { item in
                switch item {
                case let .member(member):
                    memberCell(member, in: group, size: size, width: width)
                case .invite:
                    inviteCell(size: size)
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }

    /// メンバー1人。丸は、その人が最後に撮った裏の写真（たいてい本人の顔）。撮るたびに替わる。まだ撮っていない人は頭文字。
    private func memberCell(_ member: Member, in group: RotashGroup, size: CGFloat, width: CGFloat) -> some View {
        VStack(spacing: 5) {
            memberIcon(member, in: group, size: size)
                .opacity(group.isHiddenMember(member.id) ? 0.35 : 1)
            Text(member.name.uppercased())
                .rotashLabel(8, color: member.id == group.myMemberID ? Palette.live : Palette.dim, tracking: 0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: width - 8)
        }
        // 長く押すと、その人の写真をこの端末で見えなくする／元に戻す（ブロック）。
        .contextMenu {
            if member.id != group.myMemberID {
                if group.isHiddenMember(member.id) {
                    Button { app.setMemberHidden(member.id, hidden: false) } label: {
                        Label("写真をまた表示する", systemImage: "eye")
                    }
                } else {
                    Button(role: .destructive) { app.setMemberHidden(member.id, hidden: true) } label: {
                        Label("この人の写真を見えなくする", systemImage: "eye.slash")
                    }
                }
            }
        }
    }

    private func inviteCell(size: CGFloat) -> some View {
        InviteShareButton {
            VStack(spacing: 5) {
                Circle()
                    .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: size, height: size)
                    .overlay(Text("+").rotashLabel(15, color: Palette.dim, tracking: 0))
                Text("招待する")
                    .rotashLabel(8, color: Palette.faint, tracking: 0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func memberIcon(_ member: Member, in group: RotashGroup, size: CGFloat) -> some View {
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
        .frame(width: size, height: size)
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
                Text("\(group.memories.count)").rotashLabel(10, color: Palette.faint)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)

            if group.memories.isEmpty {
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
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 24)
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

            // 招待の文章をコピーしてからアプリを入れた人のための近道。
            // 押したときだけクリップボードを読む（勝手には読まない）。
            VStack(alignment: .leading, spacing: 8) {
                Text("招待のメッセージをコピーしてきた人は")
                    .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                PasteButton(payloadType: String.self) { strings in
                    Task { @MainActor in
                        guard let code = RotashLink.code(fromPasted: strings.first) else {
                            app.alertMessage = String(localized: "招待コードが見つかりませんでした。")
                            return
                        }
                        app.pendingJoinCode = code
                        app.pendingJoinCodeIsFromLink = false
                        app.activeSheet = .join
                    }
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .tint(Palette.surface)
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 24)
    }
}
