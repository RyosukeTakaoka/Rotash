import SwiftUI
import UIKit

/// 縦向き。Rotash の入口。管理画面ではないので、ここに置くのは
/// グループ名 / 招待コード / 今日の担当者 / Memories / 設定 だけ。
/// 今週の7分割そのもの（進行中の作品）はここでは絶対に見せない。
/// 横にした瞬間に「THIS WEEK」が現れることが Rotash 独自の体験になる。
struct PortraitHomeView: View {

    @EnvironmentObject private var app: AppViewModel

    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showSettings = false
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
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RotashWeek.self) { week in
                MemoryDetailView(week: week)
            }
        }
        .tint(Palette.text)
        .sheet(isPresented: $showCreate) {
            CreateRotashView()
                .environmentObject(app)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showJoin) {
            JoinRotashView()
                .environmentObject(app)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
                Button("SETTINGS") { showSettings = true }
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

            Button {
                UIPasteboard.general.string = group.inviteCode
                copied = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                HStack(spacing: 10) {
                    Text("INVITE").rotashLabel(9, color: Palette.faint, tracking: 2)
                    Text(group.inviteCode)
                        .font(Typo.label(15, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(Palette.text)
                    Text(copied ? "COPIED" : "TAP TO COPY")
                        .rotashLabel(8, color: Palette.faint, tracking: 1.2)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                if group.currentWeek.isComplete {
                    Text("今週の作品が完成しました")
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
                VStack(spacing: 18) {
                    ForEach(group.archive) { week in
                        NavigationLink(value: week) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(week.title).rotashLabel(10, color: Palette.text, tracking: 1.2)
                                WeekThumbnailStrip(week: week)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 26)
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

            Button("ROTASH をつくる") { showCreate = true }
                .buttonStyle(RotashButtonStyle(filled: true))
            Button("招待コードで参加") { showJoin = true }
                .buttonStyle(RotashButtonStyle())
        }
        .padding(.horizontal, 24)
    }
}
