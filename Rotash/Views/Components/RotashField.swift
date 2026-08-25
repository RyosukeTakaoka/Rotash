import SwiftUI

/// 角丸もカードも使わない、下線だけの入力欄。
///
/// 日本語入力（Simeji などのサードパーティキーボードを含む）は変換中の未確定文字列を扱うので、
/// 入力中に onChange でテキストを書き換えると入力セッションが壊れる。
/// そのため通常の入力欄では文字数制限も大文字化も行わない。
///
/// 招待コードだけは英数字しか使わないので、
/// キーボード自体を ASCII に固定して日本語入力を経由させないようにし、そのうえで整形する。
struct RotashField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    /// 招待コード用の入力欄にする。
    var isInviteCode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).rotashLabel(9, color: Palette.faint, tracking: 2)
            field
            HairLine()
        }
    }

    @ViewBuilder
    private var field: some View {
        if isInviteCode {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Typo.label(16, weight: .medium))
                .tracking(4)
                .foregroundStyle(Palette.text)
                .tint(Palette.live)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: text) { _, newValue in
                    let cleaned = String(InviteCode.normalize(newValue).prefix(6))
                    if cleaned != text { text = cleaned }
                }
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Typo.label(16, weight: .medium))
                .tracking(1)
                .foregroundStyle(Palette.text)
                .tint(Palette.live)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
    }
}
