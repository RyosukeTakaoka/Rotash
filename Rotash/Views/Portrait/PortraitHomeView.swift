import SwiftUI
import UIKit

/// 縦向き。進行中の作品（写真）はここでは見せない。
/// 作る / 参加する / 招待コード / Memories / 設定 だけ。
struct PortraitHomeView: View {

    @EnvironmentObject private var app: AppViewModel

    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showSettings = false
    @State private var showImporter = false
    @State private var batonPayload: SharePayload?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    wordmark

                    if let group = app.group {
                        groupHeader(group)
                        thisWeekBlock(group)
                        memoriesBlock(group)
                        actionsBlock
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
        .sheet(isPresented: $showCreate) { CreateRotashView().environmentObject(app) }
        .sheet(isPresented: $showJoin) { JoinRotashView().environmentObject(app) }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(app) }
        .sheet(item: $batonPayload) { payload in ActivityView(items: payload.urls) }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [BatonTransfer.fileType]) { result in
            switch result {
            case .success(let url):
                do { try app.importBaton(from: url) }
                catch { app.alertMessage = error.localizedDescription }
            case .failure(let error):
                app.alertMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Blocks

    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ROTASH")
                .font(Typo.wordmark(28))
                .tracking(10)
                .foregroundStyle(Palette.text)
                .padding(.top, 28)
                .padding(.bottom, 22)
            HairLine()
        }
        .padding(.horizontal, 24)
    }

    private func groupHeader(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Text(group.members.map(\.name).joined(separator: "  ·  "))
                .rotashLabel(10, color: Palette.dim, tracking: 0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 26)
    }

    private func thisWeekBlock(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HairLine()
            HStack {
                Text("THIS WEEK").rotashLabel(10, tracking: 3)
                Spacer()
                Text("\(group.currentWeek.filledCount) / 7")
                    .rotashLabel(10, color: Palette.text)
            }
            .padding(.top, 18)

            Text(group.currentWeek.title).rotashLabel(10, color: Palette.faint)

            WeekProgressStrip(week: group.currentWeek, todayIndex: app.todayIndex)

            HStack(spacing: 8) {
                Text("TODAY").rotashLabel(9, color: Palette.faint, tracking: 2)
                Text(app.assignee(forDay: app.todayIndex)?.name.uppercased() ?? "-")
                    .rotashLabel(10, color: app.isMyDay(app.todayIndex) ? Palette.live : Palette.dim)
            }

            Text(group.currentWeek.isComplete
                 ? "今週の7枚がそろいました。横にすると作品が見られます。"
                 : "端末を横にすると、今週のRotashが見られます。")
                .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                .lineSpacing(4)
                .padding(.top, 4)
                .padding(.bottom, 22)
        }
        .padding(.horizontal, 24)
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
                                HStack {
                                    Text(week.title).rotashLabel(10, color: Palette.text, tracking: 1.2)
                                    Spacer()
                                    Text(week.isComplete ? "COMPLETE" : "\(week.filledCount) / 7")
                                        .rotashLabel(9, color: Palette.faint)
                                }
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

    private var actionsBlock: some View {
        VStack(spacing: 12) {
            HairLine().padding(.bottom, 18)

            Button("バトンを渡す") { exportBaton() }
                .buttonStyle(RotashButtonStyle())
            Button("バトンを受け取る") { showImporter = true }
                .buttonStyle(RotashButtonStyle())
            Button("設定") { showSettings = true }
                .buttonStyle(RotashButtonStyle())
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

            Text("1日にひとりだけが撮る。\n7枚そろったら完成。")
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

    private func exportBaton() {
        do {
            let url = try app.exportBaton()
            batonPayload = SharePayload(urls: [url])
        } catch {
            app.alertMessage = error.localizedDescription
        }
    }
}
