import SwiftUI

/// Rotash をつくる。
/// ここでメンバーを並べるのではなく、招待コードを配って参加してもらう形にしている。
/// 作る人は自分の名前だけ入れればよく、友達は誰かが増えるたびに勝手に加わる。
struct CreateRotashView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var myName = ""
    /// 作り終わったか。作ったあとは招待コードを見せる。
    @State private var created = false

    private var canCreate: Bool {
        !myName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            // 作り終わっていれば、作ったグループ（いま開いているグループ）の招待コードを見せる。
            // 掛け持ちできるので、「グループがあるか」では判定できない。
            if created, let group = app.group {
                InviteCodeView(group: group) { dismiss() }
            } else {
                form
            }
        }
        .presentationBackground(Palette.background)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("NEW ROTASH").rotashLabel(11, color: Palette.text, tracking: 3)
                    .padding(.top, 28)

                RotashField(title: "ROTASH の名前", placeholder: "たとえば 8月の1週間", text: $name)

                RotashField(title: "あなたの名前", placeholder: "NAME", text: $myName)

                Text("つくると招待コードが出ます。\nそのコードを渡した人が参加すると、自動でメンバーに加わります。")
                    .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                    .lineSpacing(5)

                Button("つくる") {
                    app.createRotash(name: name, memberNames: [myName])
                    created = true
                }
                .buttonStyle(RotashButtonStyle(filled: true))
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.35)

                Button("とじる") { dismiss() }
                    .buttonStyle(RotashButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}
