import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newMember = ""
    @State private var confirmDelete = false
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

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $app.freeShooting) {
                            Text("自由撮影モード")
                                .rotashLabel(11, color: Palette.text, tracking: 1)
                        }
                        .toggleStyle(.switch)
                        .tint(Palette.live)

                        Text("当番日でなくても好きな枠を撮れます。体験を試すとき用。")
                            .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                            .lineSpacing(4)
                    }

                    HairLine()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROTASH について").rotashLabel(9, color: Palette.faint, tracking: 2)
                        Text("撮るのは1日にひとりだけ。見るのはいつでも全員。\n7枚そろうと、その週の作品が完成します。\n完成した作品は Memories に残ります。")
                            .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                            .lineSpacing(5)
                    }

                    Button("とじる") { dismiss() }
                        .buttonStyle(RotashButtonStyle())

                    if app.hasGroup {
                        Button(confirmDelete ? "本当に削除する(写真も消えます)" : "この Rotash を削除") {
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
            Text("開いたときと撮ったときに、みんなの写真を取りに行きます。")
                .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                .lineSpacing(3)
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
            batonPayload = SharePayload(urls: [url])
        } catch {
            app.alertMessage = error.localizedDescription
        }
    }

    private func members(_ group: RotashGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メンバー（この順に当番がまわります）")
                .rotashLabel(9, color: Palette.faint, tracking: 1)

            ForEach(Array(group.members.enumerated()), id: \.element.id) { index, member in
                HStack(spacing: 12) {
                    Text(String(format: "%02d", index + 1)).rotashLabel(10, color: Palette.faint)
                    Text(member.name).rotashLabel(12, color: Palette.text, tracking: 0.6)
                    if member.id == group.myMemberID {
                        Text("YOU").rotashLabel(8, color: Palette.live, tracking: 1.4)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 12) {
                TextField("メンバーを追加", text: $newMember)
                    .textFieldStyle(.plain)
                    .font(Typo.label(14))
                    .foregroundStyle(Palette.text)
                    .tint(Palette.live)
                    .autocorrectionDisabled()
                    .onSubmit { add() }
                Button("追加") { add() }
                    .font(Typo.label(11, weight: .semibold))
                    .foregroundStyle(newMember.isEmpty ? Palette.faint : Palette.live)
            }
            HairLine()
        }
    }

    private func add() {
        app.addMember(name: newMember)
        newMember = ""
    }
}
