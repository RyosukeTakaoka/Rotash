import UIKit

/// 7分割の細い枠に、もっと広い範囲を収めるための「Rotash レンズ」（疑似広角）。
///
/// # なぜ要るか
///
/// 枠は 1 : 3.2 ほどの縦長で、4:3 の写真を普通に収める（aspectFill）と
/// 横幅の約8割を切り捨てている。しかも枠が縦に長すぎて、頭の上に余りができやすい。
///
/// # 何をするか
///
/// **真ん中は縦も横も同じ割合で縮める**（ズームアウト）。形は曲がらないまま、
/// 横にも縦にも `widening` 倍の範囲が入る。建物の縦線もまっすぐのまま。
///
/// ただし横持ちのカメラは、写せる高さをもう全部枠に使っている。縦も縮めると上下が足りなくなるので、
/// **写真のいちばん上と下（空・天井・床など）だけを縦に引き伸ばして** 枠を埋める。
/// 以前は横方向の端を縮めていたが（魚眼風）、「写る範囲が増えたのではなく曲がっただけ」に見えたので、
/// 崩れても目立ちにくい上下の端に歪みを寄せた。
///
/// - 写真ファイルそのものは加工しない。表示するときにだけかける。
///   だから Memories の 4:3 表示では、撮った写真の全体が自然なまま見える。
/// - ライブビュー・7分割の表示・共有画像（`.screen`）・縦持ちの撮影画面で同じ計算を使うので、
///   撮るときに見えた絵と、あとで見える絵は同じになる。
///
/// # 内カメは別の方式（左右を押し込む）
///
/// 外カメは超広角レンズで本当に広く写るので、上の疑似広角で足りる。
/// 内カメは顔の近くで撮ることが多く、欲しいのは「顔はそのまま、左右の景色も枠に入れたい」。
/// そこで内カメで撮った写真だけ、**真ん中の一定の幅はまったく縮めず、その外側だけを横に押し込む**
/// （`Style.sideSqueeze`）。最初に作った魚眼風と同じ系統だが、強すぎて端が 1/4 に潰れていたのが
/// 「曲がっただけ」に見えた原因だったので、真ん中を完全に保護し、強さも控えめにしている。
/// どちらのカメラで撮ったかは `Slot.capturedWithFront` に残し、あとで表示するときも同じ方式を使う。
enum RotashLens {

    /// どう広げるか。
    enum Style: Equatable {
        /// 真ん中を縦横そろえて縮め、足りない上下の端を伸ばす（外カメ）。
        case pseudoWide
        /// 真ん中はそのまま、左右だけを横に押し込む（内カメ）。
        case sideSqueeze
    }

    /// 1枚の写真（またはライブビュー）にかけるレンズ。
    struct Setting: Equatable {
        var style: Style
        var widening: Double

        /// かけないのと同じ。
        static let plain = Setting(style: .pseudoWide, widening: 1)

        var isActive: Bool { widening > 1.001 }
    }

    /// 撮ったカメラから、かけるレンズを決める。
    /// - Parameters:
    ///   - back: 外カメの広げ具合（`resolve(stored:)` を通したもの）
    ///   - front: 内カメの押し込み具合（`resolveFront(stored:)` を通したもの）
    static func setting(isFront: Bool, back: Double, front: Double) -> Setting {
        isFront ? Setting(style: .sideSqueeze, widening: front)
                : Setting(style: .pseudoWide, widening: back)
    }

    /// 保存済みの写真にかけるレンズ。記録が無い古い写真は外カメ扱い（これまでと同じ見え方）。
    static func setting(for slot: Slot, back: Double, front: Double) -> Setting {
        setting(isFront: slot.capturedWithFront ?? false, back: back, front: front)
    }

    /// 画面の外（共有画像など）で使う、いまの設定での写真のレンズ。
    static func currentSetting(for slot: Slot) -> Setting {
        setting(for: slot, back: widening, front: frontWidening)
    }

    /// 検証用ビルドで、設定画面から広げ具合を変えたときの保存先。
    static let storageKey = "rotash.lensWidening"

    struct Preset: Hashable {
        let label: String
        let widening: Double
    }

    /// 設定画面で選べる広げ具合。1.0 が従来どおり（中央を切り出すだけ）。
    static let presets: [Preset] = [
        Preset(label: "普通", widening: 1.0),
        Preset(label: "1.2", widening: 1.2),
        Preset(label: "1.3", widening: 1.3),
        Preset(label: "1.4", widening: 1.4)
    ]

    /// 内カメの押し込み具合を変えたときの保存先（検証用ビルド）。
    static let frontStorageKey = "rotash.frontLensWidening"

    /// 内カメで選べる押し込み具合。1.5 なら枠に 1.5 倍の横幅が入る（真ん中は縮めない）。
    static let frontPresets: [Preset] = [
        Preset(label: "普通", widening: 1.0),
        Preset(label: "1.3", widening: 1.3),
        Preset(label: "1.5", widening: 1.5),
        Preset(label: "1.8", widening: 1.8)
    ]

    /// 内カメで、まったく縮めない真ん中の幅（枠の横幅に対する割合の半分）。
    /// 0.3 なら、枠の中央 30% は撮ったときの形のまま。顔ひとつ分くらい。
    static let protectedCenter: CGFloat = 0.3

    /// 縦の引き伸ばしが破綻しない上限（真ん中の縮尺がこれを超えると、端で上下が折り返す）。
    static let maxVerticalZoom: CGFloat = 1.45

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

    /// いまの内カメの押し込み具合。
    static var frontWidening: Double {
        resolveFront(stored: UserDefaults.standard.object(forKey: frontStorageKey) as? Double)
    }

    static func resolveFront(stored: Double?) -> Double {
        guard RotashFeatureFlags.isTestBuild, let stored else { return RotashFeatureFlags.frontLensWidening }
        return max(1, stored)
    }

    // MARK: - 計算

    /// 1本の短冊。`destination` は枠の中の位置（pt）、
    /// `source` は写真のどこを持ってくるか（写真全体を 0〜1 とした割合）。
    /// 疑似広角では横は均一なので、短冊は **横長の帯**（枠の上から下へ積む）になる。
    struct Band: Equatable {
        let destination: CGRect
        let source: CGRect
    }

    /// `imageSize` の写真を `size` の枠に置くときの短冊の並びを返す。
    ///
    /// `widening` が 1 以下のときは1本だけ（= 普通の aspectFill と同じ切り出し）になる。
    ///
    /// - Parameter pixelScale: 短冊の境目を画面のピクセルに揃えるための倍率。
    ///   揃えないと、短冊のあいだに髪の毛ほどのすき間が見えることがある。
    static func bands(imageSize: CGSize,
                      in size: CGSize,
                      setting: Setting,
                      pixelScale: CGFloat) -> [Band] {
        switch setting.style {
        case .pseudoWide:
            return pseudoWideBands(imageSize: imageSize, in: size,
                                   widening: setting.widening, pixelScale: pixelScale)
        case .sideSqueeze:
            return sideSqueezeBands(imageSize: imageSize, in: size,
                                    widening: setting.widening, pixelScale: pixelScale)
        }
    }

    /// 外カメ用。真ん中を縦横そろえて縮め、足りない上下の端を伸ばす。
    static func pseudoWideBands(imageSize: CGSize,
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

        // どれだけズームアウトするか。横は写真の外まで広げられないので 1 / visibleX で止め、
        // 縦は引き伸ばしが破綻しない範囲（maxVerticalZoom / visibleY）で止める。
        let zoom = min(CGFloat(max(1, widening)), 1 / visibleX, maxVerticalZoom / visibleY)

        let plain = Band(destination: CGRect(origin: .zero, size: size),
                         source: CGRect(x: (1 - visibleX) / 2, y: (1 - visibleY) / 2,
                                        width: visibleX, height: visibleY))
        guard zoom > 1.001 else { return [plain] }

        // 横: 均一に zoom 倍の範囲。
        let widthX = visibleX * zoom
        let sourceX = (1 - widthX) / 2

        // 縦: 真ん中の縮尺は横と同じ（= 形が曲がらない）。枠の縦位置 v（上端 -1 … 下端 +1）を
        // 写真の縦位置 u へ移す。写真の高さに余裕があるうちは均一、足りなければ上下の端を伸ばす。
        //   u(v) = s·v + (1 − s)·v³    （s = 真ん中の傾き。u(±1) = ±1、s < 1.5 なら単調）
        let s = visibleY * zoom
        func sourceY(atCell v: CGFloat) -> CGFloat {
            let u = s <= 1 ? s * v : s * v + (1 - s) * v * v * v
            return 0.5 + 0.5 * u
        }

        let scale = max(pixelScale, 1)
        let heightInPixels = size.height * scale
        // 1本あたり 8px 前後。縦の引き伸ばしはゆるやかなので、この細かさで継ぎ目は見えない。
        let count = min(96, max(8, Int((heightInPixels / 8).rounded(.up))))

        var result: [Band] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let top = (heightInPixels * CGFloat(index) / CGFloat(count)).rounded()
            let bottom = (heightInPixels * CGFloat(index + 1) / CGFloat(count)).rounded()
            guard bottom > top else { continue }

            let y0 = sourceY(atCell: 2 * top / heightInPixels - 1)
            let y1 = sourceY(atCell: 2 * bottom / heightInPixels - 1)

            result.append(Band(
                destination: CGRect(x: 0, y: top / scale,
                                    width: size.width, height: (bottom - top) / scale),
                source: CGRect(x: sourceX, y: y0, width: widthX, height: y1 - y0)
            ))
        }
        return result
    }

    /// 内カメ用。真ん中（`protectedCenter`）はそのまま、その外側だけを横に押し込む。
    ///
    /// 枠の横位置 v（左端 -1 … 右端 +1）を、写真の横位置へ移す。
    ///   |v| ≤ c のとき   G(v) = v                         （縮めない）
    ///   |v| > c のとき   G(v) = v ± (k − 1)·((|v| − c)/(1 − c))²
    /// 真ん中との境目でなめらかにつながり（傾きが 1 のまま）、端の v = ±1 でちょうど k 倍の範囲に届く。
    /// 縦には手を入れないので、縦の線はまっすぐのまま。
    static func sideSqueezeBands(imageSize: CGSize,
                                 in size: CGSize,
                                 widening: Double,
                                 pixelScale: CGFloat) -> [Band] {
        guard imageSize.width > 0, imageSize.height > 0,
              size.width > 0, size.height > 0
        else { return [] }

        let fillScale = max(size.width / imageSize.width, size.height / imageSize.height)
        let visibleX = min(1, size.width / (fillScale * imageSize.width))
        let visibleY = min(1, size.height / (fillScale * imageSize.height))
        let sourceY = (1 - visibleY) / 2

        // 写真の外までは広げられないので、横は 1 / visibleX 倍で止める。
        let k = min(CGFloat(max(1, widening)), 1 / visibleX)
        guard k > 1.001 else {
            return [Band(destination: CGRect(origin: .zero, size: size),
                         source: CGRect(x: (1 - visibleX) / 2, y: sourceY,
                                        width: visibleX, height: visibleY))]
        }

        let c = protectedCenter
        func sourceX(atCell v: CGFloat) -> CGFloat {
            let a = abs(v)
            let ramp = a <= c ? 0 : (a - c) / (1 - c)
            let g = v + (v < 0 ? -1 : 1) * (k - 1) * ramp * ramp
            return 0.5 + 0.5 * visibleX * g
        }

        let scale = max(pixelScale, 1)
        let widthInPixels = size.width * scale
        // 1本あたり 3px 前後（横に押し込む方向なので、縦長の短冊を横に並べる）。
        let count = min(64, max(8, Int((widthInPixels / 3).rounded(.up))))

        var result: [Band] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let left = (widthInPixels * CGFloat(index) / CGFloat(count)).rounded()
            let right = (widthInPixels * CGFloat(index + 1) / CGFloat(count)).rounded()
            guard right > left else { continue }

            let x0 = sourceX(atCell: 2 * left / widthInPixels - 1)
            let x1 = sourceX(atCell: 2 * right / widthInPixels - 1)
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
    static func draw(_ image: UIImage, in rect: CGRect, setting: Setting) -> Bool {
        guard let cgImage = image.cgImage, image.imageOrientation == .up else { return false }

        // 組み立てる画像はピクセル単位の整数の大きさにする（倍率1）。
        let canvasSize = CGSize(width: max(1, rect.width.rounded(.up)),
                                height: max(1, rect.height.rounded(.up)))
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let pieces = Self.bands(imageSize: pixelSize, in: canvasSize, setting: setting, pixelScale: 1)
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
