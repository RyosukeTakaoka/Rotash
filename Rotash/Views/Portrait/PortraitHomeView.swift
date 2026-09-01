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
            .refreshable { await app.sync(showingError: true) }
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
            Text(group.name.uppercased())
                .font(Typo.title(20))
                .tracking(2)
                .foregroundStyle(Palette.text)

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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 30)
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
                // リストではなく積層。日付ラベルを各行から外して帯を密着させると、
                // 続いていることが「項目数」ではなく「厚み」として見える。
                //
                // 連続週数のような数字は出さない。数字は途切れた瞬間にゼロへ戻り、
                // 7人のうち誰か1人がコケるだけで壊れる（毎週およそ3割）。
                // 壊れたときに「お前のせいで切れた」が起きると、共同制作が相互監視に変わる。
                // 積み上がる一方で減らないものだけを、継続の報酬にする。
                VStack(spacing: 2) {
                    ForEach(group.archive) { week in
                        NavigationLink(value: week) {
                            WeekThumbnailStrip(week: week)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 22)

                Text("タップすると、その週を見られます。")
                    .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 24)
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
