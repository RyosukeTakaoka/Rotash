import SwiftUI

/// 角丸もカードも使わない、下線だけの入力欄。
struct RotashField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var autoUppercase: Bool = false
    var characterLimit: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).rotashLabel(9, color: Palette.faint, tracking: 2)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Typo.label(16, weight: .medium))
                .tracking(autoUppercase ? 4 : 1)
                .foregroundStyle(Palette.text)
                .tint(Palette.live)
                .textInputAutocapitalization(autoUppercase ? .characters : .words)
                .autocorrectionDisabled()
                .onChange(of: text) { _, newValue in
                    var updated = autoUppercase ? newValue.uppercased() : newValue
                    if let characterLimit, updated.count > characterLimit {
                        updated = String(updated.prefix(characterLimit))
                    }
                    if updated != text { text = updated }
                }
            HairLine()
        }
    }
}
