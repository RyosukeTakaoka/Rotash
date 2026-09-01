import SwiftUI
import UIKit

/// 写真が主役。装飾はしない。黒地・細い罫・等幅の小さなラベルだけ。
///
/// 共有画像は UIKit で描くので、色は UIColor 側を唯一の定義とし、
/// SwiftUI 側はそこから作る。画面と書き出しで色がずれないようにするため。
enum Palette {
    static let background = Color(uiColor: .rotashBackground)
    static let surface = Color(uiColor: .rotashSurface)
    static let surfaceDeep = Color(uiColor: .rotashSurfaceDeep)
    static let line = Color(uiColor: .rotashLine)
    static let text = Color(uiColor: .rotashText)
    static let dim = Color(uiColor: .rotashDim)
    static let faint = Color(uiColor: .rotashFaint)
    /// 当番であることを示すためだけに使う。
    static let live = Color(uiColor: .rotashLive)
}

extension UIColor {
    static let rotashBackground = UIColor(white: 0.04, alpha: 1)
    static let rotashSurface = UIColor(white: 0.10, alpha: 1)
    static let rotashSurfaceDeep = UIColor(white: 0.07, alpha: 1)
    static let rotashLine = UIColor(white: 0.24, alpha: 1)
    static let rotashText = UIColor(white: 0.94, alpha: 1)
    static let rotashDim = UIColor(white: 0.46, alpha: 1)
    static let rotashFaint = UIColor(white: 0.30, alpha: 1)
    static let rotashLive = UIColor(red: 0.90, green: 0.29, blue: 0.16, alpha: 1)
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
