import UIKit

/// 7分割の細い枠に、写真の横幅をもっと多く収めるための「Rotash レンズ」。
///
/// # なぜ要るか
///
/// 枠は 1 : 3.2 ほどの縦長で、4:3 の写真を普通に収める（aspectFill）と
/// 横幅の約8割を切り捨てている。自撮りなら顔が入るが、それ以外は撮るものが無くなる。
///
/// # 何をするか
///
/// 写真を細い短冊に切り、**真ん中はそのまま、端にいくほど横に縮めて** 並べ直す。
/// 縦方向には一切手を入れないので、縦の線は縦のまま、水平線も曲がらない。
/// 端の人や物が少し細くなる代わりに、同じ枠に `widening` 倍の横幅が入る。
///
/// - 写真ファイルそのものは加工しない。表示するときにだけかける。
///   だから Memories の 4:3 表示では、撮った写真の全体が自然なまま見える
///   （IMPLEMENTATION_PLAN L1「撮影は広く / 表示は7分割のまま」をそのまま満たす）。
/// - ライブビュー・7分割の表示・共有画像（`.screen`）の3か所で同じ計算を使うので、
///   撮るときに見えた絵と、あとで見える絵は同じになる。
enum RotashLens {

    /// 検証用ビルドで、設定画面から広げ具合を変えたときの保存先。
    static let storageKey = "rotash.lensWidening"

    struct Preset: Hashable {
        let label: String
        let widening: Double
    }

    /// 設定画面で選べる広げ具合。1.0 が従来どおり（中央を切り出すだけ）。
    static let presets: [Preset] = [
        Preset(label: "普通", widening: 1.0),
        Preset(label: "弱", widening: 1.5),
        Preset(label: "中", widening: 2.0),
        Preset(label: "強", widening: 2.6)
    ]

    /// いまの広げ具合。
    ///
    /// 検証用ビルドでは設定画面の値を使い、公開版では `RotashFeatureFlags.lensWidening` に固定する
    /// （公開版に「普通に戻す」スイッチを出すかどうかは、検証の結果で決める）。
    static var widening: Double {
        resolve(stored: UserDefaults.standard.object(forKey: storageKey) as? Double)
    }

    /// `@AppStorage` で持っている値から、実際に使う広げ具合を決める。
    static func resolve(stored: Double?) -> Double {
        guard RotashFeatureFlags.isTestBuild, let stored else { return RotashFeatureFlags.lensWidening }
        return max(1, stored)
    }

    // MARK: - 計算

    /// 1本の短冊。`destination` は枠の中の位置（pt）、
    /// `source` は写真のどこを持ってくるか（写真全体を 0〜1 とした割合）。
    struct Band: Equatable {
        let destination: CGRect
        let source: CGRect
    }

    /// `imageSize` の写真を `size` の枠に置くときの短冊の並びを返す。
    ///
    /// `widening` が 1 以下のとき、または枠が横長で写真の横幅がもう全部入っているときは、
    /// 1本だけ（= 普通の aspectFill と同じ切り出し）になる。
    ///
    /// - Parameter pixelScale: 短冊の境目を画面のピクセルに揃えるための倍率。
    ///   揃えないと、短冊のあいだに髪の毛ほどのすき間が見えることがある。
    static func bands(imageSize: CGSize,
                      in size: CGSize,
                      widening: Double,
                      pixelScale: CGFloat) -> [Band] {
        guard imageSize.width > 0, imageSize.height > 0,
              size.width > 0, size.height > 0
        else { return [] }

        // 普通に aspectFill したとき、写真の横・縦のうち何割が枠に見えているか。
        let fillScale = max(size.width / imageSize.width, size.height / imageSize.height)
        let visibleX = min(1, size.width / (fillScale * imageSize.width))
        let visibleY = min(1, size.height / (fillScale * imageSize.height))
        let sourceY = (1 - visibleY) / 2

        // 広げたあとに見える横幅。写真の外までは広げられないので 1 で止める。
        let widenedX = min(1, visibleX * CGFloat(max(1, widening)))
        let k = widenedX / visibleX

        guard k > 1.001 else {
            return [Band(destination: CGRect(origin: .zero, size: size),
                         source: CGRect(x: (1 - visibleX) / 2, y: sourceY,
                                        width: visibleX, height: visibleY))]
        }

        // 枠の横位置 v（左端 -1 … 右端 +1）を、写真の横位置へ移す関数。
        //   G(v) = v + (k - 1) v³
        // 真ん中の傾きが 1（= 顔などは普通の幅のまま）で、端の v = ±1 でちょうど k 倍の範囲に届く。
        // 端の傾きは 1 + 3(k - 1) で、そこがいちばん強く縮む。
        let bend = k - 1
        func sourceX(atCell v: CGFloat) -> CGFloat {
            let g = v + bend * v * v * v
            return 0.5 + 0.5 * visibleX * g
        }

        let scale = max(pixelScale, 1)
        let widthInPixels = size.width * scale
        // 1本あたり 3px 前後。細かいほど滑らかだが、層（レイヤー）の数が増える。
        let count = min(64, max(8, Int((widthInPixels / 3).rounded(.up))))

        var result: [Band] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let left = (widthInPixels * CGFloat(index) / CGFloat(count)).rounded()
            let right = (widthInPixels * CGFloat(index + 1) / CGFloat(count)).rounded()
            guard right > left else { continue }

            let v0 = 2 * left / widthInPixels - 1
            let v1 = 2 * right / widthInPixels - 1
            let x0 = sourceX(atCell: v0)
            let x1 = sourceX(atCell: v1)

            result.append(Band(
                destination: CGRect(x: left / scale, y: 0,
                                    width: (right - left) / scale, height: size.height),
                source: CGRect(x: x0, y: sourceY, width: x1 - x0, height: visibleY)
            ))
        }
        return result
    }

    // MARK: - 静止画への描画（共有画像用）

    /// 現在の UIKit の描画先に、レンズをかけた写真を `rect` いっぱいに描く。
    /// 画面の7分割と同じ見え方を、書き出す画像でも再現するために使う。
    ///
    /// 短冊を描き先へ直接並べると、枠の位置が半端な座標（例: 幅 271.7px）のとき
    /// 短冊の境目がピクセルの途中に来て、暗い縦すじが透けて見える。
    /// そこで、いったんピクセルにぴったり合った1枚の画像に組み立ててから、一度だけ描く。
    ///
    /// - Returns: 描けなかったとき（CGImage を持たない画像など）は false。呼び出し側で普通に描くこと。
    @discardableResult
    static func draw(_ image: UIImage, in rect: CGRect, widening: Double) -> Bool {
        guard let cgImage = image.cgImage, image.imageOrientation == .up else { return false }

        // 組み立てる画像はピクセル単位の整数の大きさにする（倍率1）。
        let canvasSize = CGSize(width: max(1, rect.width.rounded(.up)),
                                height: max(1, rect.height.rounded(.up)))
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let pieces = Self.bands(imageSize: pixelSize, in: canvasSize, widening: widening, pixelScale: 1)
        guard !pieces.isEmpty else { return false }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let assembled = UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            for band in pieces {
                let crop = CGRect(x: band.source.minX * pixelSize.width,
                                  y: band.source.minY * pixelSize.height,
                                  width: band.source.width * pixelSize.width,
                                  height: band.source.height * pixelSize.height).integral
                guard let piece = cgImage.cropping(to: crop) else { continue }
                UIImage(cgImage: piece).draw(in: band.destination)
            }
        }
        assembled.draw(in: CGRect(origin: rect.origin, size: canvasSize))
        return true
    }
}
