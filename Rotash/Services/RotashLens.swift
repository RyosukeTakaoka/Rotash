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

    /// 画面の外（共有画像など）で使う、いまの設定での写真のレンズ。
    static func currentSetting(for slot: Slot) -> Setting {
        setting(for: slot, back: widening, front: frontOptions)
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

    /// 内カメの広げ具合を変えたときの保存先（検証用ビルド）。
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

    /// 内カメの方式を変えたときの保存先（検証用ビルド）。
    static let frontModeKey = "rotash.frontLensMode"

    /// 内カメで、枠に入れる横幅を変えたときの保存先（検証用ビルド）。
    static let frontReachKey = "rotash.frontLensReach"

    /// 内カメで、上下の黒をぼかしで埋めるかの保存先（検証用ビルド）。
    static let frontBlurKey = "rotash.frontLensBlurFill"

    /// Apple の「内容を見て歪みを直す」補正（撮った写真にだけ効く）を使うかの保存先（検証用ビルド）。
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

    /// いまの内カメの広げ具合。
    static var frontWidening: Double {
        resolveFront(stored: UserDefaults.standard.object(forKey: frontStorageKey) as? Double)
    }

    static func resolveFront(stored: Double?) -> Double {
        guard RotashFeatureFlags.isTestBuild, let stored else { return RotashFeatureFlags.frontLensWidening }
        return max(1, stored)
    }

    /// `@AppStorage` で持っている値から、内カメのレンズの選び方を決める。公開版ではフラグの値に固定。
    static func resolveFront(mode: String?, widening: Double?, reach: Double?, blur: Bool?) -> FrontOptions {
        guard RotashFeatureFlags.isTestBuild else {
            return FrontOptions(mode: RotashFeatureFlags.frontLensMode,
                                widening: RotashFeatureFlags.frontLensWidening,
                                reach: RotashFeatureFlags.frontLensReach,
                                fillsWithBlur: RotashFeatureFlags.frontLensBlurFill)
        }
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
        let zoom = min(CGFloat(max(1, setting.widening)), 1 / visibleX)

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
