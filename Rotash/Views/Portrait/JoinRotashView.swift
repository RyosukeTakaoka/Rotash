import SwiftUI

struct JoinRotashView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var myName = ""
    @State private var fromLink = false

    private var canJoin: Bool {
        InviteCode.isValid(code) && !myName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("JOIN").rotashLabel(11, color: Palette.text, tracking: 3)
                        .padding(.top, 28)

                    // リンクから来たときはコードが分かっているので、入力させない。
                    // 打つのは名前だけ。招待の手数はここで一番減る。
                    if fromLink {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("招待コード").rotashLabel(9, color: Palette.faint, tracking: 1.6)
                            Text(code)
                                .font(Typo.label(24, weight: .semibold))
                                .tracking(8)
                                .foregroundStyle(Palette.text)
                        }
                    } else {
                        RotashField(title: "招待コード",
                                    placeholder: "XXXXXX",
                                    text: $code,
                                    isInviteCode: true)
                        // 招待の Web ページでコピーしたコード（またはリンク）を、そのまま入れる。
                        // PasteButton は押したときだけ読むので、「ペーストを許可」の確認は出ない。
                        PasteButton(payloadType: String.self) { strings in
                            Task { @MainActor in
                                if let pasted = RotashLink.code(fromPasted: strings.first) { code = pasted }
                            }
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonBorderShape(.capsule)
                        .tint(Palette.surface)
                    }

                    RotashField(title: "あなたの名前", placeholder: "NAME", text: $myName)

                    // 入った日は、今日の1枚がまだ撮られていなければ今日の番が回ってくる（AssignmentAudit.handOverToday）。
                    // もう撮られていたら、まだ来ていない日に入る。日曜の夜に入ると今週は回ってこないこともあるので、
                    // 「必ず今日」とは書かない。できない約束はしない。
                    Text(app.isSyncEnabled
                         ? "参加すると、今週の作品とメンバーがそのまま見られます。\n今日の1枚がまだ撮られていなければ、今日はあなたの番です。"
                         : "参加したら、誰かに「バトンを渡す」でその週の作品を送ってもらってください。")
                        .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                        .lineSpacing(5)

                    Button("参加する") {
                        app.joinRotash(code: code, myName: myName, viaLink: fromLink)
                        dismiss()
                    }
                    .buttonStyle(RotashButtonStyle(filled: true))
                    .disabled(!canJoin)
                    .opacity(canJoin ? 1 : 0.35)

                    Button("とじる") { dismiss() }
                        .buttonStyle(RotashButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .presentationBackground(Palette.background)
        .onAppear {
            if let pending = app.pendingJoinCode {
                code = pending
                fromLink = true
            }
        }
        // 閉じたら、リンクから来たときのコードは使い終わり（次に開いたときに入力できるように）。
        .onDisappear { app.pendingJoinCode = nil }
    }
}
