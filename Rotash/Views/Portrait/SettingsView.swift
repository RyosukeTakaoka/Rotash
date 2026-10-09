import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newMember = ""
    @State private var confirmDelete = false
    @State private var showImporter = false
    @State private var batonPayload: SharePayload?
    @AppStorage(RotashLens.storageKey) private var lensWidening = RotashFeatureFlags.lensWidening
    @AppStorage(RotashLens.frontStorageKey) private var frontLensWidening = RotashFeatureFlags.frontLensWidening
    @AppStorage(RotashLens.frontModeKey) private var frontLensMode = RotashFeatureFlags.frontLensMode.rawValue
    @AppStorage(RotashLens.frontReachKey) private var frontLensReach = RotashFeatureFlags.frontLensReach
    @AppStorage(RotashLens.appleCorrectionKey) private var appleDistortionCorrection = false
    @AppStorage(RotashLens.frontBlurKey) private var frontLensBlur = RotashFeatureFlags.frontLensBlurFill

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

                    // 自由撮影モードは当番の判定そのものを飛ばすので、
                    // 二人が同じ枠を撮れてしまう＝競合を自分から作り出す。使うときは自分でオンにする。
                    Group {
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

                        lensBlock

                        HairLine()
                    }

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

            // 担当表の照合コード。
            //
            // 同じ担当表ならどの端末でも同じ6文字になるので、複数台で見くらべれば
            // 食い違いにその場で気づける。ただしこれは「疑いながら使う」ための道具で、
            // 公開するアプリに置くものではない。担当が食い違わないこと自体は
            // AssignmentAudit が受け持っていて、そちらは本番でも常に動いている。
            if let code = app.assignmentFingerprint {
                HStack(spacing: 8) {
                    Text("担当表").rotashLabel(9, color: Palette.faint, tracking: 2)
                    Text(code)
                        .font(Typo.label(11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Palette.text)
                }
                .padding(.top, 2)
                Text("みんなで見くらべて、同じなら同じ当番表です。ちがうときは「今すぐ」で揃います。")
                    .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                    .lineSpacing(3)
            }
        }
    }

    /// Rotash レンズの広げ具合を見くらべるための切り替え。
    /// 写真ファイルは加工していないので、切り替えるとこれまでの写真の見え方も一緒に変わる。
    private var lensBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("レンズ").rotashLabel(11, color: Palette.text, tracking: 1)

            Text("外カメ（疑似広角）").rotashLabel(9, color: Palette.dim, tracking: 1)
            Picker("外カメ", selection: $lensWidening) {
                ForEach(RotashLens.presets, id: \.self) { preset in
                    Text(preset.label).tag(preset.widening)
                }
            }
            .pickerStyle(.segmented)

            Text("内カメの方式（試験中）").rotashLabel(9, color: Palette.dim, tracking: 1)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(RotashLens.FrontMode.allCases) { mode in
                    Button { frontLensMode = mode.rawValue } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(frontLensMode == mode.rawValue ? "●" : "○")
                                .rotashLabel(9, color: Palette.text)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(mode.label).rotashLabel(10, color: Palette.text, tracking: 0.6)
                                Text(mode.detail).rotashLabel(8, color: Palette.faint, tracking: 0.3)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("内カメの縮め方（上下の黒）").rotashLabel(9, color: Palette.dim, tracking: 1)
                .padding(.top, 4)
            Picker("内カメの縮め方", selection: $frontLensWidening) {
                ForEach(RotashLens.frontPresets, id: \.self) { preset in
                    Text(preset.label).tag(preset.widening)
                }
            }
            .pickerStyle(.segmented)

            Text("内カメで枠に入れる横幅（写真全体に対して）").rotashLabel(9, color: Palette.dim, tracking: 1)
                .padding(.top, 4)
            Picker("内カメの横幅", selection: $frontLensReach) {
                ForEach(RotashLens.reachPresets, id: \.self) { preset in
                    Text(preset.label).tag(preset.widening)
                }
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $frontLensBlur) {
                Text("内カメの上下の黒を、写真のぼかしで埋める")
                    .rotashLabel(9, color: Palette.dim, tracking: 0.6)
            }
            .padding(.top, 4)

            Toggle(isOn: $appleDistortionCorrection) {
                Text("Apple の歪み補正（撮った写真だけ・対応カメラのみ）")
                    .rotashLabel(9, color: Palette.dim, tracking: 0.6)
            }
            .padding(.top, 4)

            Text("撮る前のライブビューにも同じようにかかります（Apple の歪み補正だけは撮った写真にだけ効きます）。外カメは形を変えずに縮めて上下の端を伸ばします。内カメは人の形を変えずに縮めて上下を黒くし、選んだ方式で人のいない所を横に押し込みます。縦持ちの撮影画面の MODE でも方式を切り替えられます。「普通」はこれまでと同じ見え方です。")
                .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                .lineSpacing(4)
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
