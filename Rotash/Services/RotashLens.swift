import CoreImage
import CoreVideo
import UIKit
import Vision

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
/// # 内カメは曲げずに縮めて、上下を黒く欠かす（レターボックス）＋背景だけを押し込む（試験中）
///
/// 縦持ちの内カメは、写真の **高さをもう全部** 枠に使っている（枠 1:3.2、写真 3:4）。
/// 横には 2.4 倍ほど余りがあるが、縦の余りは無い。ここで「枠を埋めたまま横を増やす」と、
/// どこかを必ず曲げることになる。左右を押し込む方式（`sideSqueeze`）も、上下を伸ばす方式も、
/// 自撮りでは「魚眼のような違和感」が残った。
///
/// そこで内カメは **縦横そろえて縮める**（人の形は曲げない）ことを土台にして、
/// 縮めたぶん足りなくなる枠の上と下は黒いまま残す。映画の黒帯と同じ考え方。
/// 1.8 なら写真は枠の高さの 56% に収まり、横には普通の 1.8 倍の範囲が入る。
///
/// さらに「人はそのまま、人のいない背景だけを横に押し込んで、もっと横を入れる」方式を
/// いくつも試せるようにしている（`FrontMode`）。どれが良いかは実機で見くらべて決める。
/// どちらのカメラで撮ったかは `Slot.capturedWithFront` に残し、あとで表示するときも同じ方式を使う。
enum RotashLens {

    /// どう広げるか。
    enum Style: Equatable {
        /// 真ん中を縦横そろえて縮め、足りない上下の端を伸ばす（外カメ）。
        case pseudoWide
        /// 縦横そろえて縮め、足りない枠の上下は黒く残す。背景の押し込み方は `FrontMode` で選ぶ（内カメ）。
        case front(FrontMode)
    }

    /// 内カメで、人を守りながら背景をどう押し込むか（試験中。設定画面と撮影画面の MODE で切り替える）。
    ///
    /// どの方式も、人の形は曲げずに縦横そろえて縮め（`Setting.widening`）、上下は黒くする。
    /// そのうえで枠に写真の横幅の `Setting.reach` まで入るよう、守らない部分を横に押し込む。
    enum FrontMode: String, CaseIterable, Identifiable {
        /// 押し込まない。縮めて上下を黒くするだけ。
        case letterbox
        /// 真ん中（人がいそうな所）を固定して、左右を押し込む。人を探さない基準の方式。
        case center
        /// 人物の切り抜き（Vision）で人のいる列を守り、人から離れるほど強く押し込む。
        case person
        /// 顔（Vision）のある列だけを守る。体は少し細くなってもよいので、背景をより多く入れる。
        case face
        /// 人物に加えて「目を引く場所」（Vision の注目度）も守り、どうでもいい所ほど強く押し込む。
        case saliency
        /// 人を切り抜いて原寸のまま重ね、うしろの背景だけを均一に強く押し込む。
        case cutout
        /// シームカービング。目立たない縦の継ぎ目（空・壁など）を1本ずつ抜いて幅を詰める。人は抜かない。
        case seamCarving
        /// 押し込まず、人の位置に合わせて切り出す所を左右に動かす（パン）。
        case follow
        /// 写真の横幅を7本の細い帯に分け、帯どうしの間を飛ばして並べる（スリット風）。帯の中は曲げない。
        case slits

        var id: String { rawValue }

        /// 撮影画面のボタンに出す短い名前。
        var label: String {
            switch self {
            case .letterbox: return "黒帯"
            case .center: return "中央"
            case .person: return "人物"
            case .face: return "顔"
            case .saliency: return "重要度"
            case .cutout: return "切抜き"
            case .seamCarving: return "継ぎ目"
            case .follow: return "追従"
            case .slits: return "スリット"
            }
        }

        /// 設定画面に出す説明。
        var detail: String {
            switch self {
            case .letterbox: return "縮めて上下を黒くするだけ。押し込まない"
            case .center: return "真ん中を固定して左右を押し込む（人を探さない）"
            case .person: return "人を見つけて守り、人から離れるほど強く押し込む"
            case .face: return "顔だけを守る。体は少し細くなるが、背景が多く入る"
            case .saliency: return "人と「目を引く所」を守り、どうでもいい所ほど押し込む"
            case .cutout: return "人を切り抜いて原寸で重ね、背景だけを強く縮める"
            case .seamCarving: return "目立たない縦の筋を抜いて幅を詰める（人は抜かない）"
            case .follow: return "押し込まず、人のいる所へ切り出す位置を動かす"
            case .slits: return "写真を7本の細い帯に分けて並べる（帯の境目で絵がとぶ）"
            }
        }

        /// 次の方式（撮影画面の MODE ボタン用）。
        var next: FrontMode {
            let all = FrontMode.allCases
            let index = all.firstIndex(of: self) ?? 0
            return all[(index + 1) % all.count]
        }

        /// 枠に入れる横幅（`Setting.reach`）を使うか。黒帯だけの方式は使わない。
        var squeezes: Bool { self != .letterbox && self != .follow }
    }

    /// 1枚の写真（またはライブビュー）にかけるレンズ。
    struct Setting: Equatable {
        var style: Style
        /// 縦横そろえて縮める割合（外カメは疑似広角の広げ具合、内カメは上下の黒の量）。
        var widening: Double
        /// 内カメで、枠に入れる写真の横幅（写真全体に対する割合）。0 なら押し込まない。
        var reach: Double = 0
        /// 内カメで、上下の黒の代わりに、写真全体をぼかしたものを敷く。
        var fillsWithBlur = false

        /// かけないのと同じ。
        static let plain = Setting(style: .pseudoWide, widening: 1)

        var frontMode: FrontMode? {
            if case .front(let mode) = style { return mode }
            return nil
        }

        var isActive: Bool {
            widening > 1.001 || (frontMode?.squeezes == true && reach > 0)
        }

        /// 1枚の画像として作ってから表示する方式か（短冊に分けて並べるのでは表せないもの）。
        var needsPrerender: Bool {
            frontMode == .cutout || frontMode == .seamCarving
        }

        /// 短冊を決めるのに Vision の解析が要るか。
        var analysisNeeds: LensAnalyzer.Needs {
            switch frontMode {
            case .person, .follow: return [.person]
            case .face: return [.face]
            case .saliency: return [.person, .saliency]
            default: return []
            }
        }
    }

    /// 内カメのレンズの選び方。
    struct FrontOptions: Equatable {
        var mode: FrontMode
        var widening: Double
        var reach: Double
        var fillsWithBlur: Bool
    }

    /// 撮ったカメラから、かけるレンズを決める。
    /// - Parameters:
    ///   - back: 外カメの広げ具合（`resolve(stored:)` を通したもの）
    ///   - front: 内カメの選び方（`resolveFront(...)` を通したもの）
    static func setting(isFront: Bool, back: Double, front: FrontOptions) -> Setting {
        isFront ? Setting(style: .front(front.mode), widening: front.widening, reach: front.reach,
                          fillsWithBlur: front.fillsWithBlur)
                : Setting(style: .pseudoWide, widening: back)
    }

    /// 保存済みの写真にかけるレンズ。記録が無い古い写真は外カメ扱い（これまでと同じ見え方）。
    static func setting(for slot: Slot, back: Double, front: FrontOptions) -> Setting {
        setting(isFront: slot.capturedWithFront ?? false, back: back, front: front)
    }

    /// 裏の写真にかけるレンズ。裏の記録が無ければ内カメ扱い（裏は最初は内カメなので）。
    static func reverseSetting(for slot: Slot, back: Double, front: FrontOptions) -> Setting {
        setting(isFront: slot.reverseCapturedWithFront ?? true, back: back, front: front)
    }

    /// 画面の外（共有画像など）で使う、いまの設定での写真のレンズ。
    static func currentSetting(for slot: Slot) -> Setting {
        setting(for: slot, back: widening, front: frontOptions)
    }

    /// サムネ（7分割の枠）に、写真のどの範囲が入るか（写真全体を 0〜1 とした範囲）。
    /// 撮影画面の大きなライブビューに、その範囲を線で示すのに使う。
    static func coveredRegion(imageSize: CGSize, in size: CGSize, setting: Setting) -> CGRect {
        if setting.frontMode != nil,
           let frame = frontFrame(imageSize: imageSize, in: size, setting: setting, pixelScale: 1) {
            return CGRect(x: frame.windowMinX, y: frame.sourceY, width: frame.window, height: frame.sourceHeight)
        }
        let union = bands(imageSize: imageSize, in: size, setting: setting, pixelScale: 1)
            .reduce(CGRect.null) { $0.union($1.source) }
        return union.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : union
    }

    /// 設定画面から広げ具合を変えたときの保存先。
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

    /// 内カメの広げ具合を変えたときの保存先。
    /// 以前の曲げる方式とは見え方がまったく違うので、キーを分けて古い値を引き継がない。
    static let frontStorageKey = "rotash.frontLetterbox"

    /// 内カメで選べる広げ具合（枠に、普通の何倍の横幅を入れるか）。
    /// 写真は枠の高さの 1/広げ具合 に収まり、残りの上下は黒くなる（2.0 なら上下 25% ずつ）。
    static let frontPresets: [Preset] = [
        Preset(label: "普通", widening: 1.0),
        Preset(label: "1.5", widening: 1.5),
        Preset(label: "1.8", widening: 1.8),
        Preset(label: "2.0", widening: 2.0)
    ]

    /// 内カメの方式を変えたときの保存先。
    static let frontModeKey = "rotash.frontLensMode"

    /// 内カメで、枠に入れる横幅を変えたときの保存先。
    static let frontReachKey = "rotash.frontLensReach"

    /// 内カメで、上下の黒をぼかしで埋めるかの保存先。
    static let frontBlurKey = "rotash.frontLensBlurFill"

    /// Apple の「内容を見て歪みを直す」補正（撮った写真にだけ効く）を使うかの保存先。
    static let appleCorrectionKey = "rotash.appleDistortionCorrection"

    /// 内カメで選べる「枠に入れる横幅」（写真全体の横幅に対する割合）。
    /// 縮めるだけで入る幅（縦持ちの 1.8 なら約 74%）より狭い値を選んでも、押し込みはかからない。
    static let reachPresets: [Preset] = [
        Preset(label: "押し込まない", widening: 0),
        Preset(label: "80%", widening: 0.8),
        Preset(label: "90%", widening: 0.9),
        Preset(label: "100%", widening: 1.0)
    ]

    /// 縦の引き伸ばしが破綻しない上限（真ん中の縮尺がこれを超えると、端で上下が折り返す）。
    static let maxVerticalZoom: CGFloat = 1.45

    /// いまの広げ具合。
    ///
    /// 設定画面で選んだ値。まだ選んでいなければ `RotashFeatureFlags.lensWidening`。
    static var widening: Double {
        resolve(stored: UserDefaults.standard.object(forKey: storageKey) as? Double)
    }

    /// `@AppStorage` で持っている値から、実際に使う広げ具合を決める。
    static func resolve(stored: Double?) -> Double {
        guard let stored else { return RotashFeatureFlags.lensWidening }
        return max(1, stored)
    }

    /// いまの内カメの広げ具合。
    static var frontWidening: Double {
        resolveFront(stored: UserDefaults.standard.object(forKey: frontStorageKey) as? Double)
    }

    static func resolveFront(stored: Double?) -> Double {
        guard let stored else { return RotashFeatureFlags.frontLensWidening }
        return max(1, stored)
    }

    /// `@AppStorage` で持っている値から、内カメのレンズの選び方を決める（無ければフラグの値）。
    static func resolveFront(mode: String?, widening: Double?, reach: Double?, blur: Bool?) -> FrontOptions {
        return FrontOptions(mode: mode.flatMap(FrontMode.init(rawValue:)) ?? RotashFeatureFlags.frontLensMode,
                            widening: resolveFront(stored: widening),
                            reach: min(1, max(0, reach ?? RotashFeatureFlags.frontLensReach)),
                            fillsWithBlur: blur ?? RotashFeatureFlags.frontLensBlurFill)
    }

    /// いまの内カメのレンズの選び方。
    static var frontOptions: FrontOptions {
        let defaults = UserDefaults.standard
        return resolveFront(mode: defaults.string(forKey: frontModeKey),
                            widening: defaults.object(forKey: frontStorageKey) as? Double,
                            reach: defaults.object(forKey: frontReachKey) as? Double,
                            blur: defaults.object(forKey: frontBlurKey) as? Bool)
    }

    // MARK: - 計算

    /// 1本の短冊。`destination` は枠の中の位置（pt）、
    /// `source` は写真のどこを持ってくるか（写真全体を 0〜1 とした割合）。
    /// 外カメの疑似広角では横は均一なので、短冊は **横長の帯**（枠の上から下へ積む）になる。
    /// 内カメは横だけを曲げるので **縦長の短冊**（左から右へ並べる）になり、短冊に覆われない枠の上下が黒く見える。
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
    /// - Parameter analysis: 人物・顔・注目度の解析結果（`Setting.analysisNeeds` が空でない方式で使う）。
    ///   無いときは、人がいそうな真ん中を守る（`.center` と同じ）。
    static func bands(imageSize: CGSize,
                      in size: CGSize,
                      setting: Setting,
                      pixelScale: CGFloat,
                      analysis: LensAnalysis? = nil) -> [Band] {
        switch setting.style {
        case .pseudoWide:
            return pseudoWideBands(imageSize: imageSize, in: size,
                                   widening: setting.widening, pixelScale: pixelScale)
        case .front(let mode):
            guard let frame = frontFrame(imageSize: imageSize, in: size, setting: setting, pixelScale: pixelScale)
            else { return [] }
            switch mode {
            case .follow:
                return [followBand(frame: frame, in: size, analysis: analysis)]
            case .slits:
                return slitBands(frame: frame, in: size, pixelScale: pixelScale)
            default:
                break
            }
            // 1枚の画像として作る方式（切り抜き・シームカービング）は、出来上がるまで黒帯だけで出す。
            guard frame.window > frame.natural + 0.001, !setting.needsPrerender else {
                return [frame.plainBand(in: size)]
            }
            let profile = importanceProfile(mode: mode, analysis: analysis, natural: frame.natural)
            return warpedBands(frame: frame, in: size, pixelScale: pixelScale, importance: profile)
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
        let s = visibleY * zoom
        func sourceY(atCell v: CGFloat) -> CGFloat {
            0.5 + 0.5 * cubicProfile(v, slope: s)
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

    /// 外カメの縦の割り当て。真ん中の傾きが s で、上下の端 v = ±1 でちょうど写真の端に届く。
    ///   u(v) = s·v + (1 − s)·v³    （u(±1) = ±1、s < 1.5 なら単調）
    static func cubicProfile(_ v: CGFloat, slope s: CGFloat) -> CGFloat {
        s <= 1 ? s * v : s * v + (1 - s) * v * v * v
    }

    // MARK: - 内カメ

    /// 内カメの写真を枠に置くときの形（上下の黒・枠に入れる横幅）。
    /// 横の値は写真全体の横幅を 1、縦の値は写真全体の高さを 1 とした割合。高さ・位置は枠の座標（pt）。
    struct FrontFrame: Equatable {
        /// 形を変えずに縮めたとき、枠の横幅に入る写真の横幅。
        let natural: CGFloat
        /// 押し込んで枠に入れる写真の横幅（natural 以上）。真ん中そろえ。
        let window: CGFloat
        /// 写真の縦のうち、使う範囲（上端と高さ）。
        let sourceY: CGFloat
        let sourceHeight: CGFloat
        /// 枠の中で写真が占める縦の範囲。上下の残りが黒になる。
        let photoTop: CGFloat
        let photoHeight: CGFloat

        var windowMinX: CGFloat { (1 - window) / 2 }

        /// 押し込まず、縮めるだけの1枚。
        func plainBand(in size: CGSize) -> Band {
            Band(destination: CGRect(x: 0, y: photoTop, width: size.width, height: photoHeight),
                 source: CGRect(x: (1 - natural) / 2, y: sourceY, width: natural, height: sourceHeight))
        }
    }

    /// 写真を縦横そろえて `widening` 倍ぶん縮め、枠の上下中央に置いたときの形を返す。
    ///
    /// 横は写真の外までは広げられないので 1 / visibleX 倍で止める。
    /// 縦は、写真の高さに余りがあるうち（visibleY < 1）はその余りから使い、
    /// 足りなくなったら写真の高さ全体を枠より低く置く。覆われない枠の上下は、描く側の背景（黒）が見える。
    static func frontFrame(imageSize: CGSize, in size: CGSize, setting: Setting, pixelScale: CGFloat) -> FrontFrame? {
        guard imageSize.width > 0, imageSize.height > 0,
              size.width > 0, size.height > 0
        else { return nil }

        let fillScale = max(size.width / imageSize.width, size.height / imageSize.height)
        let visibleX = min(1, size.width / (fillScale * imageSize.width))
        let visibleY = min(1, size.height / (fillScale * imageSize.height))
        // 縦に長い写真（上下に振ったパノラマなど）は、高さに余りがあるぶん、縮めなくても横が入る。
        // 普通の 3:4 の写真を widening 倍に縮めたときと同じ横の範囲が入るところで止めて、上下の黒を減らす。
        let aspect = imageSize.width / imageSize.height
        let widening = aspect < 0.75 ? max(1, CGFloat(setting.widening) * aspect / 0.75)
                                     : CGFloat(max(1, setting.widening))
        let zoom = min(widening, 1 / visibleX)

        // 縮めたあと、枠の高さぶんに写真の高さの何割が要るか。1 を超えたぶんが上下の黒になる。
        let neededY = visibleY * zoom
        let natural = min(1, visibleX * zoom)
        let reach = setting.frontMode?.squeezes == true ? CGFloat(setting.reach) : 0
        let window = min(1, max(natural, reach))
        let sourceHeight = min(1, neededY)

        // 写真が枠の中で占める高さ。上下の境目は画面のピクセルに揃える。
        let scale = max(pixelScale, 1)
        let photoHeight = neededY > 1 ? size.height / neededY : size.height
        let top = ((size.height - photoHeight) / 2 * scale).rounded() / scale
        return FrontFrame(natural: natural, window: window,
                          sourceY: (1 - sourceHeight) / 2, sourceHeight: sourceHeight,
                          photoTop: top, photoHeight: size.height - 2 * top)
    }

    /// 写真の横位置（0〜1）ごとの「守りたさ」（0〜1）。`LensAnalysis.bins` 等分した値で持つ。
    /// 1 の所は縮めるだけ（形はそのまま）、0 に近い所ほど強く押し込む。
    ///
    /// 守る所から離れるにつれて、なめらかに守りたさを下げる（いきなり切り替えると、人の輪郭に折れ目が出る）。
    static func importanceProfile(mode: FrontMode, analysis: LensAnalysis?, natural: CGFloat) -> [CGFloat] {
        let bins = LensAnalysis.bins
        // 守る所の両側で、守りたさを 1 → 0 へ下げていく幅（写真の横幅に対する割合）。
        let ramp = max(0.02, 0.3 * natural)

        func centerColumns() -> [CGFloat] {
            (0..<bins).map { (index: Int) -> CGFloat in
                let x = (CGFloat(index) + 0.5) / CGFloat(bins)
                return abs(x - 0.5) <= natural / 4 ? 1 : 0
            }
        }
        /// 守る列（0.5 以上）から離れるほど下げる。
        func falloff(_ columns: [CGFloat]) -> [CGFloat] {
            let protected = columns.indices.filter { columns[$0] >= 0.5 }
            guard !protected.isEmpty else { return falloff(centerColumns()) }
            return (0..<bins).map { (index: Int) -> CGFloat in
                let distance = protected.map { abs($0 - index) }.min() ?? bins
                let t = min(1, CGFloat(distance) / CGFloat(bins) / ramp)
                return 1 - t * t * (3 - 2 * t)
            }
        }

        switch mode {
        case .letterbox, .center, .cutout, .seamCarving, .follow, .slits:
            return falloff(centerColumns())
        case .person:
            return falloff((analysis?.person ?? []).map { $0 > 0.03 ? CGFloat(1) : 0 })
        case .face:
            return falloff(analysis?.face ?? [])
        case .saliency:
            let person = falloff((analysis?.person ?? []).map { $0 > 0.03 ? CGFloat(1) : 0 })
            guard let saliency = analysis?.saliency, saliency.count == bins else { return person }
            return (0..<bins).map { max(person[$0], saliency[$0]) }
        }
    }

    /// 横だけを曲げる短冊。守りたさ I の所は縮めるだけ（傾き = natural）、そうでない所は
    ///   押し込みの強さ c = 1 + λ·(1 − I)
    /// で、さらに c 倍に押し込む。λ は「枠に入れる横幅（window）がちょうど枠に収まる」ように二分探索で決める。
    /// 守る所が広すぎて収まらないときは、全体を少しずつ押し込んで収める。
    static func warpedBands(frame: FrontFrame, in size: CGSize, pixelScale: CGFloat,
                            importance: [CGFloat]) -> [Band] {
        let samples = 256
        let dx = frame.window / CGFloat(samples)
        let bins = importance.count
        let weights: [CGFloat] = (0..<samples).map { (index: Int) -> CGFloat in
            let x = frame.windowMinX + (CGFloat(index) + 0.5) * dx
            let position = min(CGFloat(bins) - 1, max(0, x * CGFloat(bins) - 0.5))
            let lower = Int(position), upper = min(bins - 1, lower + 1)
            let t = position - CGFloat(lower)
            let value = bins > 0 ? importance[lower] * (1 - t) + importance[upper] * t : 0
            return 1 - min(1, max(0, value))
        }

        // 枠の横幅を 1 としたとき、この λ で写真の窓がどれだけの幅になるか。
        func total(_ lambda: CGFloat) -> CGFloat {
            weights.reduce(0) { $0 + dx / (frame.natural * (1 + lambda * $1)) }
        }
        var lambda: CGFloat = 0
        if total(0) > 1.0001 {
            var low: CGFloat = 0, high: CGFloat = 60
            if total(high) > 1 {
                lambda = high
            } else {
                for _ in 0..<40 {
                    let mid = (low + high) / 2
                    if total(mid) > 1 { low = mid } else { high = mid }
                }
                lambda = high
            }
        }

        // 窓の左端から、各サンプルまでの枠の上での位置（0〜1 にそろえる）。
        var cumulative: [CGFloat] = [0]
        cumulative.reserveCapacity(samples + 1)
        for weight in weights {
            cumulative.append(cumulative[cumulative.count - 1] + dx / (frame.natural * (1 + lambda * weight)))
        }
        let span = cumulative[samples]
        guard span > 0 else { return [frame.plainBand(in: size)] }

        /// 枠の位置 u（0〜1）に来る、写真の横位置。
        var searchIndex = 0
        func sourceX(atCell u: CGFloat) -> CGFloat {
            let target = u * span
            while searchIndex < samples - 1, cumulative[searchIndex + 1] < target { searchIndex += 1 }
            let start = cumulative[searchIndex], end = cumulative[searchIndex + 1]
            let t = end > start ? (target - start) / (end - start) : 0
            return frame.windowMinX + (CGFloat(searchIndex) + min(1, max(0, t))) * dx
        }

        let scale = max(pixelScale, 1)
        let widthInPixels = size.width * scale
        // 1本あたり 3px 前後。
        let count = min(160, max(16, Int((widthInPixels / 3).rounded(.up))))
        var edges: [CGFloat] = []
        edges.reserveCapacity(count + 1)
        for index in 0...count {
            edges.append((widthInPixels * CGFloat(index) / CGFloat(count)).rounded())
        }
        var sources: [CGFloat] = []
        sources.reserveCapacity(edges.count)
        for edge in edges { sources.append(sourceX(atCell: edge / widthInPixels)) }

        var result: [Band] = []
        result.reserveCapacity(count)
        for index in 0..<count where edges[index + 1] > edges[index] {
            result.append(Band(
                destination: CGRect(x: edges[index] / scale, y: frame.photoTop,
                                    width: (edges[index + 1] - edges[index]) / scale, height: frame.photoHeight),
                source: CGRect(x: sources[index], y: frame.sourceY,
                               width: sources[index + 1] - sources[index], height: frame.sourceHeight)
            ))
        }
        return result
    }

    /// 押し込まずに、人の横の中心が枠の真ん中に来るよう切り出す所を動かす（写真の外へははみ出さない）。
    /// 人が見つからないときは真ん中を切り出す。
    static func followBand(frame: FrontFrame, in size: CGSize, analysis: LensAnalysis?) -> Band {
        let center = analysis?.personCenter ?? 0.5
        let x = min(max(0, center - frame.natural / 2), 1 - frame.natural)
        return Band(destination: CGRect(x: 0, y: frame.photoTop, width: size.width, height: frame.photoHeight),
                    source: CGRect(x: x, y: frame.sourceY, width: frame.natural, height: frame.sourceHeight))
    }

    /// 枠を7本の帯に分け、写真の窓（`frame.window`）の横幅を均等に7か所から切り出して並べる。
    /// 帯の中は縮めるだけ（形はそのまま）で、帯と帯のあいだの写真は飛ばす。
    /// 窓が縮めるだけで入る幅と同じなら、普通の1枚と同じになる。
    static func slitBands(frame: FrontFrame, in size: CGSize, pixelScale: CGFloat) -> [Band] {
        let slits = 7
        let scale = max(pixelScale, 1)
        let widthInPixels = size.width * scale
        let sliceWidth = frame.natural / CGFloat(slits)
        var result: [Band] = []
        for index in 0..<slits {
            let left = (widthInPixels * CGFloat(index) / CGFloat(slits)).rounded()
            let right = (widthInPixels * CGFloat(index + 1) / CGFloat(slits)).rounded()
            guard right > left else { continue }
            let center = frame.windowMinX + frame.window * (CGFloat(index) + 0.5) / CGFloat(slits)
            result.append(Band(
                destination: CGRect(x: left / scale, y: frame.photoTop,
                                    width: (right - left) / scale, height: frame.photoHeight),
                source: CGRect(x: center - sliceWidth / 2, y: frame.sourceY,
                               width: sliceWidth, height: frame.sourceHeight)
            ))
        }
        return result
    }

    /// 1枚の画像として作る方式（切り抜き・シームカービング）の絵を、枠のピクセルの大きさで作る。
    /// 上下の黒も含めた、枠いっぱいの画像を返す。重いので、画面のスレッドでは呼ばないこと。
    /// - Parameter live: ライブビュー用（速さを優先して、解析と組み立てを軽くする）。
    static func prerender(_ image: CGImage, size: CGSize, scale: CGFloat, setting: Setting, live: Bool) -> CGImage? {
        let canvas = CGSize(width: max(1, (size.width * scale).rounded()),
                            height: max(1, (size.height * scale).rounded()))
        guard let frame = frontFrame(imageSize: CGSize(width: image.width, height: image.height),
                                     in: canvas, setting: setting, pixelScale: 1)
        else { return nil }
        switch setting.frontMode {
        case .cutout:
            return LensCompositor.cutout(image, frame: frame, canvas: canvas, live: live,
                                         transparentBars: setting.fillsWithBlur)
        case .seamCarving:
            return LensCompositor.seamCarved(image, frame: frame, canvas: canvas, live: live,
                                             transparentBars: setting.fillsWithBlur)
        default:
            return nil
        }
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
        let canvasRect = CGRect(origin: .zero, size: canvasSize)

        // 1枚の画像として作る方式は作った絵を、それ以外は短冊を描く。
        var rendered: CGImage?
        var pieces: [Band] = []
        if setting.needsPrerender {
            rendered = prerender(cgImage, size: canvasSize, scale: 1, setting: setting, live: false)
            guard rendered != nil else { return false }
        } else {
            let needs = setting.analysisNeeds
            let analysis = needs.isEmpty ? nil : LensAnalyzer.analyze(cgImage, needs: needs, live: false)
            pieces = Self.bands(imageSize: pixelSize, in: canvasSize, setting: setting,
                                pixelScale: 1, analysis: analysis)
            guard !pieces.isEmpty else { return false }
        }

        // 上下をぼかしで埋めるときは、写真全体をぼかして枠いっぱいに敷く（画面の LensView と同じ見え方）。
        let backdrop = setting.fillsWithBlur && setting.frontMode != nil
            ? LensCompositor.blurredBackdrop(cgImage, canvas: canvasSize) : nil

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let assembled = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            // 内カメは短冊が枠の上下を覆わないので、そこは画面と同じく黒（またはぼかし）にする。
            UIColor.black.setFill()
            context.fill(canvasRect)
            if let backdrop {
                UIImage(cgImage: backdrop).draw(in: canvasRect)
                UIColor(white: 0, alpha: LensCompositor.backdropDimming).setFill()
                context.fill(canvasRect, blendMode: .normal)
            }
            if let rendered {
                UIImage(cgImage: rendered).draw(in: canvasRect)
            }
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

// MARK: - Vision の解析（人物・顔・注目度）

/// 写真（またはライブビューの1コマ）の「どこに人がいるか」を、横の位置ごとにまとめたもの。
///
/// どの値も、写真の横幅を `bins` 等分したそれぞれの列について 0〜1 で持つ。
/// 列ごとの値にしておくと、ライブビューで前のコマとなめらかにつなぐ（`blended`）のが簡単になる。
struct LensAnalysis: Equatable {
    static let bins = 128

    /// 人物の切り抜き（マスク）が、その列の高さのうち何割を占めるか。
    var person: [CGFloat]?
    /// 顔（少し余白を足した範囲）がかかっている列は 1、そうでない列は 0。
    var face: [CGFloat]?
    /// 注目度（人が見そうな所）の、その列でいちばん高い値。いちばん高い列を 1 にそろえる。
    var saliency: [CGFloat]?

    /// 人物の横の中心（写真の横幅を 1 とした位置）。人が見つからなければ nil。
    var personCenter: CGFloat? {
        guard let person else { return nil }
        let total = person.reduce(0, +)
        guard total > 0.05 else { return nil }
        let weighted = person.indices.reduce(CGFloat(0)) { $0 + (CGFloat($1) + 0.5) * person[$1] }
        return weighted / total / CGFloat(person.count)
    }

    /// ライブビューで、前の解析結果となめらかにつなぐ（毎回ぱっと変わると、背景がガタガタ揺れる）。
    func blended(from previous: LensAnalysis?, amount: CGFloat = 0.4) -> LensAnalysis {
        guard let previous else { return self }
        func mix(_ new: [CGFloat]?, _ old: [CGFloat]?) -> [CGFloat]? {
            guard let new else { return nil }
            guard let old, old.count == new.count else { return new }
            return new.indices.map { old[$0] + (new[$0] - old[$0]) * amount }
        }
        return LensAnalysis(person: mix(person, previous.person),
                            face: mix(face, previous.face),
                            saliency: mix(saliency, previous.saliency))
    }
}

/// Vision で、人物・顔・注目度を調べる。どれも重いので、画面のスレッドでは呼ばないこと。
enum LensAnalyzer {

    /// 何を調べるか。
    struct Needs: OptionSet {
        let rawValue: Int
        static let person = Needs(rawValue: 1 << 0)
        static let face = Needs(rawValue: 1 << 1)
        static let saliency = Needs(rawValue: 1 << 2)
    }

    /// - Parameter live: ライブビュー用（人物の切り抜きを速い設定にする）。
    static func analyze(_ image: CGImage, needs: Needs, live: Bool) -> LensAnalysis {
        var result = LensAnalysis()
        guard !needs.isEmpty else { return result }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let personRequest = VNGeneratePersonSegmentationRequest()
        personRequest.qualityLevel = live ? .fast : .balanced
        personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let faceRequest = VNDetectFaceRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        var requests: [VNRequest] = []
        if needs.contains(.person) { requests.append(personRequest) }
        if needs.contains(.face) { requests.append(faceRequest) }
        if needs.contains(.saliency) { requests.append(saliencyRequest) }

        do {
            try handler.perform(requests)
        } catch {
            #if DEBUG
            print("🔍 レンズの解析に失敗:", error)
            #endif
            return result
        }

        if needs.contains(.person), let mask = personRequest.results?.first?.pixelBuffer {
            result.person = columns(ofMask: mask)
        }
        if needs.contains(.face) {
            result.face = faceColumns(faceRequest.results ?? [])
        }
        if needs.contains(.saliency), let heatmap = saliencyRequest.results?.first?.pixelBuffer {
            result.saliency = columns(ofHeatmap: heatmap)
        }
        return result
    }

    /// 人物の切り抜き（マスク）。白い所が人。
    /// - Parameter live: ライブビュー用（速い設定）。写真の表示・共有画像ではきれいな設定にする。
    static func personMask(_ image: CGImage, live: Bool) -> CVPixelBuffer? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = live ? .balanced : .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            return nil
        }
        return request.results?.first?.pixelBuffer
    }

    /// マスクの各列で、人が高さの何割を占めるか。
    static func columns(ofMask mask: CVPixelBuffer) -> [CGFloat] {
        let bins = LensAnalysis.bins
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return [] }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        guard width > 0, height > 0 else { return [] }
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        var hits = [Int](repeating: 0, count: bins)
        var samples = [Int](repeating: 0, count: bins)
        for x in 0..<width {
            let bin = min(bins - 1, x * bins / width)
            for y in stride(from: 0, to: height, by: 2) {
                if pixels[y * bytesPerRow + x] > 127 { hits[bin] += 1 }
                samples[bin] += 1
            }
        }
        return (0..<bins).map { samples[$0] > 0 ? CGFloat(hits[$0]) / CGFloat(samples[$0]) : 0 }
    }

    /// 顔のある列を 1 にする。顔の幅の 20% ずつ余白を足して、耳や髪まで守る。
    static func faceColumns(_ faces: [VNFaceObservation]) -> [CGFloat] {
        let bins = LensAnalysis.bins
        var result = [CGFloat](repeating: 0, count: bins)
        for face in faces {
            // boundingBox は 0〜1 の割合。横の向きは画像と同じ（左が 0）。
            let box = face.boundingBox
            let margin = box.width * 0.2
            let start = max(0, Int(((box.minX - margin) * CGFloat(bins)).rounded(.down)))
            let end = min(bins - 1, Int(((box.maxX + margin) * CGFloat(bins)).rounded(.up)))
            guard start <= end else { continue }
            for index in start...end { result[index] = 1 }
        }
        return result
    }

    /// 注目度の地図（小さな 32bit 小数の画像）の各列の最大値。いちばん高い列を 1 にそろえる。
    static func columns(ofHeatmap heatmap: CVPixelBuffer) -> [CGFloat] {
        let bins = LensAnalysis.bins
        CVPixelBufferLockBaseAddress(heatmap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(heatmap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(heatmap),
              CVPixelBufferGetPixelFormatType(heatmap) == kCVPixelFormatType_OneComponent32Float
        else { return [] }
        let width = CVPixelBufferGetWidth(heatmap)
        let height = CVPixelBufferGetHeight(heatmap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(heatmap)
        guard width > 0, height > 0 else { return [] }

        var columnMax = [Float](repeating: 0, count: width)
        for y in 0..<height {
            let row = (base + y * bytesPerRow).assumingMemoryBound(to: Float.self)
            for x in 0..<width { columnMax[x] = max(columnMax[x], row[x]) }
        }
        let peak = max(columnMax.max() ?? 0, 0.0001)
        return (0..<bins).map { (index: Int) -> CGFloat in
            let x = min(width - 1, index * width / bins)
            return CGFloat(columnMax[x] / peak)
        }
    }
}

// MARK: - 1枚の画像として組み立てる方式（切抜き・継ぎ目）

/// 短冊を並べるだけでは作れない内カメの方式を、1枚の画像として組み立てる（試験中）。
///
/// - `cutout`: 人を切り抜いて原寸のまま重ね、うしろの背景だけを均一に強く押し込む
/// - `seamCarved`: シームカービング。目立たない縦の継ぎ目を1本ずつ抜いて幅を詰める
///
/// どちらも上下の黒を含めた「枠いっぱいの画像」を返す。重いので、画面のスレッドでは呼ばないこと。
enum LensCompositor {

    /// Core Image の描画先。作るのが重いので使い回す（複数のスレッドから使ってよい）。
    private static let context = CIContext(options: [.cacheIntermediates: false])

    // MARK: - 人を切り抜いて重ねる

    /// 背景: 枠に入れる横幅（`frame.window`）を、そのまま枠の横幅へ均一に押し込む。
    /// 人: 縮めるだけ（形はそのまま）で、人の中心が「押し込んだ背景の中で人がいた位置」に来るように重ねる。
    ///
    /// 背景にも人は写っているが、押し込まれて細くなった人は同じ中心にいるので、重ねた原寸の人に隠れる。
    /// 人が見つからないときは、押し込まずに縮めるだけの絵になる。
    /// - Parameter transparentBars: 上下を黒にせず透明にする（下にぼかしを敷くとき）。
    static func cutout(_ image: CGImage, frame: RotashLens.FrontFrame, canvas: CGSize, live: Bool,
                       transparentBars: Bool) -> CGImage? {
        let imageWidth = CGFloat(image.width), imageHeight = CGFloat(image.height)
        let canvasRect = CGRect(origin: .zero, size: canvas)
        // Core Image は左下が原点。写真が占める帯（上下の黒を除いた所）。
        let band = CGRect(x: 0, y: canvas.height - frame.photoTop - frame.photoHeight,
                          width: canvas.width, height: frame.photoHeight)
        let sourceBottom = (1 - frame.sourceY - frame.sourceHeight) * imageHeight
        let scaleY = frame.photoHeight / (frame.sourceHeight * imageHeight)

        let source = CIImage(cgImage: image)
        let mask = LensAnalyzer.personMask(image, live: live)
        let center = mask.flatMap { LensAnalysis(person: LensAnalyzer.columns(ofMask: $0)).personCenter }

        // 人の層。人の中心 xp が、押し込んだ背景の中の同じ位置 up に来るように置く。
        let personX = center ?? 0.5
        let cellX = min(0.95, max(0.05, (personX - frame.windowMinX) / frame.window))
        let personScale = canvas.width / (frame.natural * imageWidth)
        let personTransform = CGAffineTransform(a: personScale, b: 0, c: 0, d: scaleY,
                                                tx: cellX * canvas.width - personX * imageWidth * personScale,
                                                ty: band.minY - sourceBottom * scaleY)
        let person = source.transformed(by: personTransform).cropped(to: band)

        let black = transparentBars ? CIImage.empty() : CIImage(color: .black).cropped(to: canvasRect)
        var output = person.composited(over: black)

        if let mask, center != nil {
            // 背景の層。窓全体を枠の横幅へ均一に押し込む。
            let backgroundScale = canvas.width / (frame.window * imageWidth)
            let backgroundTransform = CGAffineTransform(a: backgroundScale, b: 0, c: 0, d: scaleY,
                                                        tx: -frame.windowMinX * imageWidth * backgroundScale,
                                                        ty: band.minY - sourceBottom * scaleY)
            let background = source.transformed(by: backgroundTransform).cropped(to: band)

            // マスクは写真より小さいので、写真の大きさに広げてから人の層と同じように置く。
            let maskImage = CIImage(cvPixelBuffer: mask)
            let toImage = CGAffineTransform(scaleX: imageWidth / maskImage.extent.width,
                                            y: imageHeight / maskImage.extent.height)
            let placedMask = maskImage.transformed(by: toImage.concatenating(personTransform)).cropped(to: band)

            let blended = person.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: background,
                kCIInputMaskImageKey: placedMask
            ])
            output = blended.cropped(to: band).composited(over: black)
        }

        return context.createCGImage(output.cropped(to: canvasRect), from: canvasRect)
    }

    // MARK: - 上下のぼかし

    /// ぼかしの上にかける黒の濃さ（画面の `UIBlurEffect(style: .dark)` に近づける）。
    static let backdropDimming: CGFloat = 0.35

    /// 写真全体を枠いっぱいに広げて（aspectFill）強くぼかした画像。共有画像の上下を埋めるのに使う。
    static func blurredBackdrop(_ image: CGImage, canvas: CGSize) -> CGImage? {
        let canvasRect = CGRect(origin: .zero, size: canvas)
        let source = CIImage(cgImage: image)
        let fill = max(canvas.width / source.extent.width, canvas.height / source.extent.height)
        let placed = source
            .transformed(by: CGAffineTransform(scaleX: fill, y: fill))
            .transformed(by: CGAffineTransform(translationX: (canvas.width - source.extent.width * fill) / 2,
                                               y: (canvas.height - source.extent.height * fill) / 2))
        let blurred = placed.clampedToExtent()
            .applyingGaussianBlur(sigma: Double(max(canvas.width, canvas.height)) * 0.03)
            .cropped(to: canvasRect)
        return context.createCGImage(blurred, from: canvasRect)
    }

    // MARK: - シームカービング

    /// シームカービング（Avidan & Shamir, 2007）。
    ///
    /// 画像の「目立ち具合」（となりの画素との明るさの差）を求め、上から下まで目立たない所をつないだ
    /// 1本の縦の継ぎ目（シーム）を見つけて抜く。これを繰り返して、枠に入れる横幅を縮めるだけの幅まで詰める。
    /// 空や壁のような平らな所から抜けていくので、人や物の形は残りやすい。人物の切り抜きの所は抜かない。
    ///
    /// 重いので、小さくした画像で計算する（ライブビューは高さ 320px、写真は 900px）。
    /// - Parameter transparentBars: 上下を黒にせず透明にする（下にぼかしを敷くとき）。
    static func seamCarved(_ image: CGImage, frame: RotashLens.FrontFrame, canvas: CGSize, live: Bool,
                           transparentBars: Bool) -> CGImage? {
        let imageWidth = CGFloat(image.width), imageHeight = CGFloat(image.height)
        let crop = CGRect(x: frame.windowMinX * imageWidth, y: frame.sourceY * imageHeight,
                          width: frame.window * imageWidth, height: frame.sourceHeight * imageHeight).integral
        guard crop.width >= 8, crop.height >= 8, let region = image.cropping(to: crop) else { return nil }

        let height = max(8, min(live ? 320 : 900, Int(crop.height)))
        let width = max(8, Int((crop.width * CGFloat(height) / crop.height).rounded()))
        let target = max(4, min(width, Int((CGFloat(width) * frame.natural / frame.window).rounded())))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        // 小さくした画像の画素（1画素 = RGBA を 1 つの UInt32 に）。
        guard let work = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                   bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo),
              let workData = work.data
        else { return nil }
        work.interpolationQuality = .medium
        work.draw(region, in: CGRect(x: 0, y: 0, width: width, height: height))
        let count = width * height
        var pixels = Array(UnsafeBufferPointer(start: workData.bindMemory(to: UInt32.self, capacity: count),
                                               count: count))

        // 目立ち具合。行 0 が画像の上。
        var energy = [Float](repeating: 0, count: count)
        pixels.withUnsafeBufferPointer { px in
            var luma = [Float](repeating: 0, count: count)
            for index in 0..<count {
                let value = px[index]
                // バイトの並びは R, G, B, A（byteOrder32Big）。リトルエンディアンの UInt32 では R が下位。
                let r = Float(value & 0xFF), g = Float((value >> 8) & 0xFF), b = Float((value >> 16) & 0xFF)
                luma[index] = 0.299 * r + 0.587 * g + 0.114 * b
            }
            for y in 0..<height {
                let row = y * width
                let up = max(0, y - 1) * width, down = min(height - 1, y + 1) * width
                for x in 0..<width {
                    let left = max(0, x - 1), right = min(width - 1, x + 1)
                    energy[row + x] = abs(luma[row + right] - luma[row + left])
                        + abs(luma[down + x] - luma[up + x])
                }
            }
        }

        // 人物の切り抜きの所は、ぜったいに抜かれないよう目立ち具合をとても大きくする。
        if let mask = LensAnalyzer.personMask(image, live: live) {
            protect(&energy, width: width, height: height, mask: mask, frame: frame)
        }

        removeSeams(pixels: &pixels, energy: &energy, width: width, height: height, target: target)

        // 詰めた画像（target × height）を作る。
        guard let carvedContext = CGContext(data: nil, width: target, height: height, bitsPerComponent: 8,
                                            bytesPerRow: target * 4, space: colorSpace, bitmapInfo: bitmapInfo),
              let carvedData = carvedContext.data
        else { return nil }
        let carvedPixels = carvedData.bindMemory(to: UInt32.self, capacity: target * height)
        for y in 0..<height {
            for x in 0..<target { carvedPixels[y * target + x] = pixels[y * width + x] }
        }
        guard let carved = carvedContext.makeImage() else { return nil }

        // 枠いっぱいの画像に、上下の黒をつけて置く（CGContext は左下が原点）。
        guard let output = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height),
                                     bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                     bitmapInfo: bitmapInfo)
        else { return nil }
        output.clear(CGRect(origin: .zero, size: canvas))
        if !transparentBars {
            output.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            output.fill(CGRect(origin: .zero, size: canvas))
        }
        output.interpolationQuality = .high
        output.draw(carved, in: CGRect(x: 0, y: canvas.height - frame.photoTop - frame.photoHeight,
                                       width: canvas.width, height: frame.photoHeight))
        return output.makeImage()
    }

    /// 人物のマスクが白い所の目立ち具合を、抜かれないほど大きくする。
    private static func protect(_ energy: inout [Float], width: Int, height: Int,
                                mask: CVPixelBuffer, frame: RotashLens.FrontFrame) {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return }
        let maskWidth = CVPixelBufferGetWidth(mask), maskHeight = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        guard maskWidth > 0, maskHeight > 0 else { return }
        let maskPixels = base.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            // 小さくした画像の (x, y) が、写真全体のどこにあたるか（0〜1、上が 0）。
            let imageY = frame.sourceY + frame.sourceHeight * (CGFloat(y) + 0.5) / CGFloat(height)
            let maskY = min(maskHeight - 1, max(0, Int(imageY * CGFloat(maskHeight))))
            for x in 0..<width {
                let imageX = frame.windowMinX + frame.window * (CGFloat(x) + 0.5) / CGFloat(width)
                let maskX = min(maskWidth - 1, max(0, Int(imageX * CGFloat(maskWidth))))
                if maskPixels[maskY * bytesPerRow + maskX] > 127 {
                    energy[y * width + x] += 100_000
                }
            }
        }
    }

    /// いちばん目立たない縦の継ぎ目を、幅が `target` になるまで1本ずつ抜く。
    /// 画素と目立ち具合は、行の幅（width）を変えずに左へ詰めていく（右端の使わなくなった所は捨てる）。
    /// 抜くたびに目立ち具合を計算し直すのは重いので、最初に求めた値を一緒に詰めて使い回す。
    private static func removeSeams(pixels: inout [UInt32], energy: inout [Float],
                                    width: Int, height: Int, target: Int) {
        guard target < width, height > 0 else { return }
        var cost = [Float](repeating: 0, count: width * height)

        pixels.withUnsafeMutableBufferPointer { px in
            energy.withUnsafeMutableBufferPointer { en in
                cost.withUnsafeMutableBufferPointer { co in
                    var current = width
                    while current > target {
                        // 上から下へ、各画素まで継ぎ目をつないだときのいちばん小さい目立ち具合の合計。
                        for x in 0..<current { co[x] = en[x] }
                        for y in 1..<max(1, height) {
                            let row = y * width, previous = row - width
                            for x in 0..<current {
                                var best = co[previous + x]
                                if x > 0, co[previous + x - 1] < best { best = co[previous + x - 1] }
                                if x < current - 1, co[previous + x + 1] < best { best = co[previous + x + 1] }
                                co[row + x] = en[row + x] + best
                            }
                        }

                        // いちばん下の行で最小の所から、上へたどりながら抜く。
                        let lastRow = (height - 1) * width
                        var seamX = 0
                        for x in 1..<max(1, current) where co[lastRow + x] < co[lastRow + seamX] { seamX = x }
                        var y = height - 1
                        while y >= 0 {
                            let row = y * width
                            if seamX < current - 1 {
                                for x in seamX..<(current - 1) {
                                    px[row + x] = px[row + x + 1]
                                    en[row + x] = en[row + x + 1]
                                }
                            }
                            if y > 0 {
                                let previous = row - width
                                var next = seamX
                                if seamX > 0, co[previous + seamX - 1] < co[previous + next] { next = seamX - 1 }
                                if seamX < current - 1, co[previous + seamX + 1] < co[previous + next] { next = seamX + 1 }
                                seamX = next
                            }
                            y -= 1
                        }
                        current -= 1
                    }
                }
            }
        }
    }
}
