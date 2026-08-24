import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newMember = ""
    @State private var confirmDelete = false

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
                        Button(confirmDelete ? "本当に削除する（写真も消えます）" : "この Rotash を削除") {
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
