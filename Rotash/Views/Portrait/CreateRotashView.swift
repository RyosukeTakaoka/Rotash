import SwiftUI

struct CreateRotashView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var myName = ""
    @State private var members: [String] = []
    @State private var newMember = ""
    @State private var created = false

    private var canCreate: Bool {
        !myName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
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

                RotashField(title: "あなたの名前", placeholder: "NAME", text: $myName, characterLimit: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text("メンバー（追加した順に当番がまわります）")
                        .rotashLabel(9, color: Palette.faint, tracking: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        memberRow(index: 1, name: myName.isEmpty ? "あなた" : myName)
                        ForEach(Array(members.enumerated()), id: \.offset) { index, member in
                            memberRow(index: index + 2, name: member) {
                                members.remove(at: index)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        TextField("メンバーを追加", text: $newMember)
                            .textFieldStyle(.plain)
                            .font(Typo.label(14))
                            .foregroundStyle(Palette.text)
                            .tint(Palette.live)
                            .autocorrectionDisabled()
                            .onSubmit { addMember() }
                        Button("追加") { addMember() }
                            .font(Typo.label(11, weight: .semibold))
                            .foregroundStyle(newMember.isEmpty ? Palette.faint : Palette.live)
                            .disabled(newMember.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    HairLine()
                }

                Text("撮るのは1日にひとりだけですが、\n7分割はメンバー全員がいつでも見られます。")
                    .rotashLabel(10, color: Palette.dim, tracking: 0.4)
                    .lineSpacing(5)

                Button("つくる") {
                    app.createRotash(name: name, memberNames: [myName] + members)
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

    private func memberRow(index: Int, name: String, onDelete: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index)).rotashLabel(10, color: Palette.faint)
            Text(name).rotashLabel(12, color: Palette.text, tracking: 0.6)
            Spacer()
            if let onDelete {
                Button("削除") { onDelete() }
                    .font(Typo.label(9))
                    .foregroundStyle(Palette.faint)
            }
        }
    }

    private func addMember() {
        let cleaned = newMember.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        members.append(cleaned)
        newMember = ""
    }
}
