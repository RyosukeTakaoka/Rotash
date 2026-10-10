import SwiftUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDelete = false
    @State private var copied = false
    @State private var showImporter = false
    @State private var batonPayload: SharePayload?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("SETTINGS").rotashLabel(11, color: Palette.text, tracking: 3)
                        .padding(.top, 28)

                    if let group = app.group {
                        // 掛け持ちしているとき、どのグループの設定かが分かるように。
                        Text(group.name.uppercased())
                            .font(Typo.title(18))
                            .tracking(1.5)
                            .foregroundStyle(Palette.text)
                        members(group)
                        HairLine()
                        // 同期が使えるときはそちらが主。使えないときだけバトンを出す。
                        if app.isSyncEnabled {
                            syncBlock
                        } else {
                            batonBlock
                        }
                        HairLine()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROTASH について").rotashLabel(9, color: Palette.faint, tracking: 2)
                        Text("撮るのは1日にひとりだけ。見るのはいつでも全員。\n日曜日が終わると、その週の作品が完成します。\n完成した作品は Memories に残ります。")
                            .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                            .lineSpacing(5)
                    }

                    Button("とじる") { dismiss() }
                        .buttonStyle(RotashButtonStyle())

                    if app.hasGroup {
                        Button(confirmDelete ? "本当に抜ける（この端末からこのグループの写真が消えます）" : "このグループから抜ける") {
                            if confirmDelete {
                                app.deleteRotash()
                                dismiss()
                            } else {
                                confirmDelete = true
                            }
                        }
                        .font(Typo.label(10))
                        .tracking(1)
                        .foregroundStyle(confirmDelete ? Palette.live : Palette.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .presentationBackground(Palette.background)
        .sheet(item: $batonPayload) { payload in ActivityView(items: payload.items) }
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

    private var syncBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("同期").rotashLabel(9, color: Palette.faint, tracking: 2)
                if app.isSyncing {
                    Text("SYNCING").rotashLabel(9, color: Palette.live, tracking: 1.4)
                } else if let date = app.lastSyncedAt {
                    Text(RotashDateFormat.time.string(from: date))
                        .rotashLabel(9, color: Palette.dim, tracking: 0.6)
                }
                Spacer()
                Button("今すぐ") {
                    Task { await app.sync(showingError: true) }
                }
                .font(Typo.label(11, weight: .semibold))
                .foregroundStyle(Palette.text)
                .disabled(app.isSyncing)
            }
            Text("開いたとき・横にしたとき・撮ったときに、自動でみんなの写真を取りに行きます。")
                .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                .lineSpacing(3)

            if let note = app.syncNote {
                Text(note)
                    .rotashLabel(9, color: Palette.live, tracking: 0.4)
                    .lineSpacing(3)
            }

        }
    }

    private var batonBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("バトン（同期を使わずに、ファイルで手渡しします）")
                .rotashLabel(9, color: Palette.faint, tracking: 0.6)
                .lineSpacing(3)
            HStack(spacing: 20) {
                Button("渡す") { exportBaton() }
                    .font(Typo.label(11, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Button("受け取る") { showImporter = true }
                    .font(Typo.label(11, weight: .semibold))
                    .foregroundStyle(Palette.text)
            }
        }
    }

    private func exportBaton() {
        do {
            let url = try app.exportBaton()
            batonPayload = SharePayload(items: [url])
        } catch {
            app.alertMessage = error.localizedDescription
        }
    }

    private func members(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メンバー（この順に当番がまわります）")
                .rotashLabel(9, color: Palette.faint, tracking: 1)

            // 抜けた人は当番に入らないので、ここには出さない（過去の作品には名前が残る）。
            ForEach(Array(group.activeMembers.enumerated()), id: \.element.id) { index, member in
                HStack(spacing: 12) {
                    Text(String(format: "%02d", index + 1)).rotashLabel(10, color: Palette.faint)
                    Text(member.name).rotashLabel(12, color: Palette.text, tracking: 0.6)
                    if member.id == group.myMemberID {
                        Text("YOU").rotashLabel(8, color: Palette.live, tracking: 1.4)
                    }
                    Spacer()
                }
            }

            // メンバーは、招待コードで本人が参加して増える（名前だけの人をここで足すことはしない。
            // 足しても撮る端末が無いので、その人の当番の日はいつも写真のない日になってしまう）。
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    InviteShareButton {
                        Text("＋ 招待する")
                            .rotashLabel(11, color: Palette.live, tracking: 1)
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    Text(group.inviteCode)
                        .font(Typo.label(13, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(Palette.text)
                    Button(copied ? "コピーしました" : "コードをコピー") {
                        UIPasteboard.general.string = group.inviteCode
                        copied = true
                    }
                    .font(Typo.label(9))
                    .foregroundStyle(Palette.faint)
                }
                Text("招待コードを入れた人が、そのままメンバーに加わります。まだ来ていない日があれば、今週の当番にも入ります。")
                    .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                    .lineSpacing(3)
            }
            HairLine()
        }
    }
}
