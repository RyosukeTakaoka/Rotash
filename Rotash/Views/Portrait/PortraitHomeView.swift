import SwiftUI
import UIKit

/// 縦向き。Rotash の入口。管理画面ではないので、ここに置くのは
/// グループ名 / 招待コード / 今日の1マス / メンバー / Memories / 設定 だけ。
/// 今週の7分割そのもの（進行中の作品）はここでは見せない。見せるのは撮られた写真を1枚ずつ（`PhotoCarousel`）。
/// 真ん中がいちばん新しく撮られた1枚で、左にそれより前の写真がのぞく（まだ1枚も無いときは今日の1マス、`TodayCard`）。
/// メンバーの丸は写真の上に横一列。Memories は先週の作品だけを小さく置き、全部は別の画面（`MemoriesView`）。
/// 縦のホームを1画面に収めるため（2026-10-15）。
/// 横にした瞬間に「THIS WEEK」が現れることが Rotash 独自の体験になる。
struct PortraitHomeView: View {

    @EnvironmentObject private var app: AppViewModel

    @State private var copied = false
    /// 全画面で大きく見ている写真（写真の並びの真ん中を押すと開く）。
    @State private var viewing: ViewerTarget?

    private struct ViewerTarget {
        let item: PhotoCarousel.Item
        /// 裏返したまま開いたか（全画面も裏から見せる）。
        let reversed: Bool
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let group = app.group {
                    // ちょうど1画面。スクロールしなくても全部見える（引っぱって更新はできる）。
                    // 余った高さは、今日の1マスが使う（機種ごとに画面の高さが違っても、はみ出さない）。
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        groupBlock(group)
                        memoriesBlock(group)
                    }
                    .containerRelativeFrame(.vertical)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        onboarding
                    }
                    .padding(.bottom, 40)
                }
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
        // 横の7分割で写真を押したときと同じ全画面。
        .overlay {
            if let viewing {
                PhotoViewer(slot: viewing.item.slot,
                            week: viewing.item.week,
                            name: app.group.flatMap { photographerName(viewing.item, in: $0) },
                            showsDate: true,
                            startsReversed: viewing.reversed) {
                    withAnimation(.easeOut(duration: 0.2)) { self.viewing = nil }
                }
                .id(viewing.item.id)
                .transition(.opacity)
            }
        }
        .sheet(item: $app.activeSheet) { sheet in
            Group {
                switch sheet {
                case .create: CreateRotashView()
                case .join: JoinRotashView()
                case .settings: SettingsView()
                case .messages: GroupChatView()
                }
            }
            .environmentObject(app)
            // メッセージは、下に引いて閉じてもよい（書きかけを失っても困らない）。
            .interactiveDismissDisabled(sheet != .messages)
        }
    }

    // MARK: - Blocks

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 右のボタンはアイコンなので、文字の下の線ではなく真ん中でそろえる。
            HStack(alignment: .center) {
                Text("ROTASH")
                    .font(Typo.wordmark(28))
                    .tracking(10)
                    .foregroundStyle(Palette.text)
                Spacer()
                if RotashFeatureFlags.groupMessages, app.group != nil {
                    messagesButton
                        .padding(.trailing, 18)
                }
                Button { app.activeSheet = .settings } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Palette.faint)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("設定"))
            }
            .padding(.top, 18)
            .padding(.bottom, 16)
            HairLine()
        }
        .padding(.horizontal, 24)
    }

    /// グループのひとことへの入口。まだ読んでいないものがあれば、その数を当番の色で添える。
    private var messagesButton: some View {
        let unread = app.unreadMessageCount
        return Button { app.activeSheet = .messages } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(unread > 0 ? Palette.text : Palette.faint)
                    .frame(minHeight: 32)
                if unread > 0 {
                    Text(unread > 99 ? "99+" : "\(unread)")
                        .font(Typo.label(9, weight: .semibold))
                        .foregroundStyle(Palette.live)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unread > 0 ? Text("メッセージ（未読 \(unread) 件）") : Text("メッセージ"))
    }

    private func groupBlock(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            groupSwitcher(group)

            HStack(alignment: .firstTextBaseline) {
                // 招待で送るのは6桁のコードではなく、いまの作品そのもの。
                // 受け取った側は、見ただけで何のアプリか分かる。
                InviteShareButton {
                    HStack(spacing: 10) {
                        Text("INVITE").rotashLabel(9, color: Palette.faint, tracking: 2)
                        Text(group.inviteCode)
                            .font(Typo.label(15, weight: .semibold))
                            .tracking(4)
                            .foregroundStyle(Palette.text)
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.live)
                    }
                }
                .accessibilityLabel(Text("招待コード \(group.inviteCode) を送る"))
                Spacer(minLength: 8)
                // 対面でそのまま伝えたいときのために、コピーも残しておく（1画面に収めるため、同じ行に）。
                Button {
                    UIPasteboard.general.string = group.inviteCode
                    copied = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text(copied ? "コードをコピーしました" : "コードをコピー")
                        .rotashLabel(9, color: Palette.faint, tracking: 0.8)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                let photos = recentPhotos(in: group)

                if group.currentWeek.isFinished {
                    Text("今週の作品ができました")
                        .rotashLabel(11, color: Palette.text, tracking: 0.6)
                } else if !photos.isEmpty, isMyTurnToShoot(in: group) {
                    // 真ん中は今日の1マスではなく撮られた写真なので、自分の番であることはここで伝える。
                    Text("今日はあなたの番 ・ 横にして撮る")
                        .rotashLabel(11, color: Palette.live, tracking: 0.6)
                }

                membersRow(group)
                    .padding(.top, 4)

                if photos.isEmpty {
                    // まだ1枚も撮られていないときは、今日の1マス。ほかを置いて余った高さを全部使う。
                    TodayCard(week: group.currentWeek,
                              hides: { app.isHidden($0) },
                              todayIndex: app.todayIndex,
                              assigneeName: app.revealedAssignee(forDay: app.todayIndex)?.name,
                              isMine: app.isMyDay(app.todayIndex))
                        .aspectRatio(TodayCard.aspect, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 12)
                } else {
                    // 撮られた写真の並び。ほかを置いて余った高さを全部使う。
                    // 左右の余白（24pt）の外まで広げて、隣の写真が画面の端までのぞけるようにする。
                    PhotoCarousel(items: photos,
                                  currentWeekID: group.currentWeek.id,
                                  todayIndex: app.todayIndex,
                                  name: { photographerName($0, in: group) }) { item, reversed in
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewing = ViewerTarget(item: item, reversed: reversed)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, -24)
                    .padding(.top, 12)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    /// 撮られた写真を新しい順に（今週と、これまでの週の全部）。この端末で見えなくしている写真は入れない。
    private func recentPhotos(in group: RotashGroup) -> [PhotoCarousel.Item] {
        ([group.currentWeek] + group.archive)
            .flatMap { week in
                week.slots
                    .filter { $0.isFilled && !group.isHidden($0) }
                    .map { PhotoCarousel.Item(slot: $0, week: week) }
            }
            .sorted { $0.takenAt > $1.takenAt }
    }

    /// 撮った人の名前（記録の無い古い写真は、その日の担当）。
    private func photographerName(_ item: PhotoCarousel.Item, in group: RotashGroup) -> String? {
        (item.slot.takenByMemberID ?? item.slot.assigneeID).flatMap { group.member(withID: $0)?.name }
    }

    /// 今日が自分の番で、まだ撮っていないか。
    private func isMyTurnToShoot(in group: RotashGroup) -> Bool {
        app.isMyDay(app.todayIndex) && !(group.currentWeek.slot(at: app.todayIndex)?.isFilled ?? false)
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
                .padding(.top, 14)
                .padding(.bottom, 10)
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
            // 1枚は正方形で、いつも7枚ぶんの幅で割る（週の途中から始めた2枚だけの週でも、写真が大きくならないように）。
            Color.clear
                .aspectRatio(7, contentMode: .fit)
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        let gap: CGFloat = 2
                        let count = CGFloat(max(week.slots.count, 1))
                        let side = (geometry.size.width - gap * 6) / 7
                        WeekThumbnailStrip(week: week, height: side, hides: { app.isHidden($0) })
                            .frame(width: side * count + gap * (count - 1))
                    }
                }
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
