import SwiftUI
import UIKit

struct InviteCodeView: View {
    let group: RotashGroup
    var onDone: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INVITE CODE").rotashLabel(11, color: Palette.text, tracking: 3)
                .padding(.top, 40)

            Text(group.inviteCode)
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .tracking(10)
                .foregroundStyle(Palette.text)
                .padding(.top, 30)
                .padding(.bottom, 22)

            HairLine()

            Text("このコードを友達に渡してください。\n参加したら「バトンを渡す」でその週の作品を送れます。")
                .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                .lineSpacing(5)
                .padding(.top, 20)

            Spacer()

            Button(copied ? "コピーしました" : "コードをコピー") {
                UIPasteboard.general.string = group.inviteCode
                copied = true
            }
            .buttonStyle(RotashButtonStyle())
            .padding(.bottom, 12)

            Button("はじめる") { onDone() }
                .buttonStyle(RotashButtonStyle(filled: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }
}
