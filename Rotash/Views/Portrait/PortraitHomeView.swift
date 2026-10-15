import SwiftUI
import UIKit

/// 縦向き。Rotash の入口。管理画面ではないので、ここに置くのは
/// グループ名 / 招待コード / 今日の1マス / メンバー / Memories / 設定 だけ。
/// 今週の7分割そのもの（進行中の作品）はここでは見せない。見せるのは今日の1マスだけ（`TodayCard`）。
/// メンバーの丸は今日の1マスの上に横一列。Memories は先週の作品だけを小さく置き、全部は別の画面（`MemoriesView`）。
/// 縦のホームを1画面に収めるため（2026-10-15）。
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
        VStack(alignment: .leading, spacing: 12) {
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

                membersRow(group)
                    .padding(.top, 4)

                // 今日の1マス（縦は「1日」、横は「1週間」）。真ん中に、画面の半分弱の高さで。
                TodayCard(week: group.currentWeek,
                          hides: { app.isHidden($0) },
                          todayIndex: app.todayIndex,
                          assigneeName: app.revealedAssignee(forDay: app.todayIndex)?.name,
                          isMine: app.isMyDay(app.todayIndex))
                    .aspectRatio(TodayCard.aspect, contentMode: .fit)
                    .containerRelativeFrame(.vertical) { length, _ in length * 0.46 }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 24)
    }

    /// メンバー。丸は、その人が最後に撮った裏の写真（たいてい本人の顔）。撮るたびに替わる。
    /// まだ撮っていない人は頭文字。最後に招待の丸を置く（7人そろったら出さない）。
    /// 収まるときは真ん中にそろえ、収まらないときは横にすべらせる。
    private func membersRow(_ group: RotashGroup) -> some View {
        let row = HStack(alignment: .top, spacing: 18) {
            ForEach(group.activeMembers) { member in
                memberCell(member, in: group)
            }
            if group.activeMembers.count < RotashGroup.capacity {
                inviteCell
            }
        }
        return ViewThatFits(in: .horizontal) {
            row.frame(maxWidth: .infinity)
            ScrollView(.horizontal) { row }
                .scrollIndicators(.hidden)
        }
    }

    private static let memberSize: CGFloat = 48

    private func memberCell(_ member: Member, in group: RotashGroup) -> some View {
        VStack(spacing: 6) {
            memberIcon(member, in: group, size: Self.memberSize)
                .opacity(group.isHiddenMember(member.id) ? 0.35 : 1)
            Text(member.name.uppercased())
                .rotashLabel(8, color: member.id == group.myMemberID ? Palette.live : Palette.dim, tracking: 0.6)
                .lineLimit(1)
                .frame(maxWidth: 56)
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

    private var inviteCell: some View {
        InviteShareButton {
            VStack(spacing: 6) {
                Circle()
                    .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: Self.memberSize, height: Self.memberSize)
                    .overlay(Text("+").rotashLabel(16, color: Palette.dim, tracking: 0))
                Text("招待する")
                    .rotashLabel(8, color: Palette.faint, tracking: 0.6)
                    .lineLimit(1)
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

    /// Memories。ホームには先週（いちばん新しい）作品だけを小さく置く。全部は「MEMORIES」から別の画面で。
    private func memoriesBlock(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HairLine()
            NavigationLink {
                MemoriesView()
            } label: {
                HStack {
                    Text("MEMORIES").rotashLabel(10, tracking: 3)
                    Spacer()
                    Text("\(group.memories.count)").rotashLabel(10, color: Palette.faint)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                }
                .padding(.top, 18)
                .padding(.bottom, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let latest = group.memories.first {
                NavigationLink(value: latest) {
                    latestRow(latest)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            } else {
                Text("完成した作品はまだありません。")
                    .rotashLabel(10, color: Palette.faint, tracking: 0.4)
                    .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 24)
    }

    /// 先週の作品。名前と日付を1行に、その下に7枚を小さく並べる。
    private func latestRow(_ week: RotashWeek) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if let title = week.title, !title.isEmpty {
                    Text(title)
                        .font(Typo.title(16))
                        .tracking(0.5)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                Text(week.dateRange)
                    .rotashLabel(10, color: Palette.dim, tracking: 1.2)
                    .lineLimit(1)
            }
            WeekThumbnailStrip(week: week, height: nil, hides: { app.isHidden($0) })
                .aspectRatio(CGFloat(max(week.slots.count, 1)), contentMode: .fit)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
