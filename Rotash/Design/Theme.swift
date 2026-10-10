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

/// 裏（もう一方のカメラ）の丸の決まりごと。撮るときの丸・枠の下の丸・共有画像の丸で同じにする。
///
/// 丸の中身は、写真（4:3）の中に入るいちばん大きな丸（直径＝写真の短い辺）を縮めたもの。
/// 丸いっぱいに広げる（aspectFill）と、ちょうどこれになり、上下に黒い帯も出ない。
enum ReverseBadge {
    /// 丸の直径を、7分割の1枠の幅の何倍にするか。
    static let widthRatio: CGFloat = 0.8
    /// 丸を枠の下の端からどれだけ離すか（pt）。右下に置くときは右の端からも同じだけ離す。
    static let bottomInset: CGFloat = 10
    /// 丸の直径の上限（枠の高さに対する割合）。
    ///
    /// 週の途中から始めた最初の週は枠が1〜3つしかなく、1枠が横に広い。
    /// 幅だけで決めると丸が枠からはみ出すほど大きくなるので、高さで上限を決める。
    /// ふだんの7分割（細い枠）はこの上限に届かないので、見た目は変わらない。
    static let maxHeightRatio: CGFloat = 0.3

    /// 枠の大きさから、丸の直径と置き方を決める。
    /// 細い枠は下の真ん中（7つの丸が一列にそろう）。上限に届くほど広い枠は右下
    /// （真ん中に置くと、横に広い写真の主役をふさぐため）。
    ///
    /// 右下に移るのは、上限よりはっきり広いとき（幅で決めた直径が上限の 1.25 倍を超えるとき）だけ。
    /// 境目ぎりぎりの枠（6枠の週など）で、端末や共有画像によって置き方が変わらないように。
    static func placement(in cell: CGSize) -> (diameter: CGFloat, centered: Bool) {
        let byWidth = cell.width * widthRatio
        let cap = cell.height * maxHeightRatio
        return (min(byWidth, cap), byWidth <= cap * 1.25)
    }
}

/// 作品（7分割）の1枠の形。縦の画面で作品を小さく見せるときも、横画面で見る作品と同じ形にそろえる。
enum WorkShape {
    private static let measuredKey = "rotash.landscapeCellAspect"

    /// 横画面の7分割の1枠の「幅 ÷ 高さ」。
    ///
    /// 横画面で実際に測った値（`recordLandscapeCell`）があればそれを使う。
    /// まだ一度も横にしていなければ、画面の大きさと安全領域（ノッチ・ホームバーのぶん）から見積もる。
    @MainActor static var cellAspect: CGFloat {
        let measured = UserDefaults.standard.double(forKey: measuredKey)
        if measured > 0.05, measured < 2 { return measured }
        return estimatedCellAspect
    }

    /// 枠が `count` 個の週の1枠の形。週の途中から始めた最初の週は枠が少ないぶん、1枠が横に広い
    /// （7分割の帯全体の形は変わらない）。
    @MainActor static func cellAspect(forSlots count: Int) -> CGFloat {
        cellAspect * 7 / CGFloat(max(1, min(7, count)))
    }

    /// 7分割の帯全体の「幅 ÷ 高さ」（枠どうしのすきまは小さいので無視する）。枠の数によらず同じ。
    @MainActor static var stripAspect: CGFloat { cellAspect * 7 }

    /// 横画面の7分割（7枠の週）で測った1枠の大きさを覚える。
    @MainActor static func recordLandscapeCell(width: CGFloat, height: CGFloat) {
        guard width > 0, height > 0 else { return }
        let aspect = Double(width / height)
        if abs(UserDefaults.standard.double(forKey: measuredKey) - aspect) > 0.001 {
            UserDefaults.standard.set(aspect, forKey: measuredKey)
        }
    }

    /// 画面から見積もった1枠の形。横画面の幅＝縦の高さ、高さ＝縦の幅から見出し（約40pt）を引いたもの。
    /// ノッチのある iPhone は、横にすると左右に安全領域（縦のときの上の余白と同じくらい）と、
    /// 下にホームバーのぶん（約21pt）が入る。
    @MainActor private static var estimatedCellAspect: CGFloat {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let screen = scene?.screen.bounds.size ?? CGSize(width: 390, height: 844)
        let short = min(screen.width, screen.height)
        let long = max(screen.width, screen.height)
        let insets = scene?.windows.first?.safeAreaInsets ?? .zero
        let notch = max(insets.top, insets.left) > 24
        let side = notch ? max(insets.top, insets.left) : 0
        let width = max(long - side * 2, 1)
        let height = max(short - (notch ? 21 : 0) - 40, 1)
        return (width / 7) / height
    }
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
