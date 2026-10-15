import SwiftUI
import UIKit

struct SettingsView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDelete = false
    @State private var showImporter = false
    @State private var batonPayload: SharePayload?

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // とじるは、下まで行かなくても押せるよう右上にも置く（指の届く大きさで）。
                    HStack(alignment: .center) {
                        Text("SETTINGS").rotashLabel(11, color: Palette.text, tracking: 3)
                        Spacer()
                        Button { dismiss() } label: {
                            Text("とじる")
                                .rotashLabel(11, color: Palette.text, tracking: 1.6)
                                .frame(minWidth: 64, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)

                    if let group = app.group {
                        // 掛け持ちしているとき、どのグループの設定かが分かるように。
                        Text(group.name.uppercased())
                            .font(Typo.title(18))
                            .tracking(1.5)
                            .foregroundStyle(Palette.text)
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

                    // 報告・問い合わせの連絡先（App Store ガイドライン 1.2）。設定されているときだけ出す。
                    if !SyncConfig.supportEmail.isEmpty,
                       let mail = URL(string: "mailto:\(SyncConfig.supportEmail)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("お問い合わせ・報告").rotashLabel(9, color: Palette.faint, tracking: 2)
                            Link(SyncConfig.supportEmail, destination: mail)
                                .font(Typo.label(11, weight: .semibold))
                                .foregroundStyle(Palette.text)
                            Text("困った写真は、写真の「…」から報告できます。")
                                .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                        }
                    }

                    Button("とじる") { dismiss() }
                        .buttonStyle(RotashButtonStyle())

                    if app.hasGroup {
                        Button("このグループから抜ける") { confirmDelete = true }
                            .font(Typo.label(10))
                            .tracking(1)
                            .foregroundStyle(Palette.faint)
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
        // 抜けるとき、自分の写真を友達の作品に残すか、いっしょに消すかを選ぶ。
        // 消すほうは「アカウントとデータの削除」にあたる（App Store ガイドライン 5.1.1(v)）。
        .confirmationDialog("このグループから抜けますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("抜ける（写真は友達の作品に残す）", role: .destructive) {
                app.deleteRotash()
                dismiss()
            }
            Button("抜けて、自分が撮った写真も消す", role: .destructive) {
                app.deleteRotash(withdrawingPhotos: true)
                dismiss()
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("この端末からは、このグループと写真が消えます。写真も消すと、みんなの作品からあなたの写真と名前が消え、元に戻せません。")
        }
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
}
