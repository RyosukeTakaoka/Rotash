import SwiftUI

/// 写真が主役。装飾はしない。黒地・細い罫・等幅の小さなラベルだけ。
enum Palette {
    static let background = Color(white: 0.04)
    static let surface = Color(white: 0.10)
    static let surfaceDeep = Color(white: 0.07)
    static let line = Color(white: 0.24)
    static let text = Color(white: 0.94)
    static let dim = Color(white: 0.46)
    static let faint = Color(white: 0.30)
    /// 当番であることを示すためだけに使う。
    static let live = Color(red: 0.90, green: 0.29, blue: 0.16)
}

enum Typo {
    static func label(_ size: CGFloat = 11, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
    static func wordmark(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

extension Text {
    /// 小さい等幅ラベル。すべて大文字＋字間で「アーカイブ感」を出す。
    func rotashLabel(_ size: CGFloat = 11,
                     color: Color = Palette.dim,
                     tracking: CGFloat = 1.6) -> some View {
        self.font(Typo.label(size))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

/// 角丸なし・塗りなしの素っ気ないボタン。
struct RotashButtonStyle: ButtonStyle {
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.label(13, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(filled ? Palette.background : Palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(filled ? Palette.text : Color.clear)
            .overlay(Rectangle().stroke(filled ? Color.clear : Palette.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct HairLine: View {
    var body: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 1)
    }
}
