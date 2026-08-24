import SwiftUI

struct JoinRotashView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var myName = ""

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

                    RotashField(title: "招待コード",
                                placeholder: "XXXXXX",
                                text: $code,
                                autoUppercase: true,
                                characterLimit: 6)

                    RotashField(title: "あなたの名前", placeholder: "NAME", text: $myName, characterLimit: 12)

                    Text("参加したら、誰かに「バトンを渡す」でその週の作品を送ってもらってください。\nメンバーと当番の順番は、受け取ったバトンに合わせて更新されます。")
                        .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                        .lineSpacing(5)

                    Button("参加する") {
                        app.joinRotash(code: code, myName: myName)
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
    }
}
