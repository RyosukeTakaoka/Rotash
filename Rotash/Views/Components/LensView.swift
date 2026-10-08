import SwiftUI
import UIKit

/// `RotashLens` の短冊を、そのまま CALayer の並びとして表示する View。
///
/// 1枚の画像を短冊の数だけのレイヤーに共有させ、それぞれの `contentsRect` で
/// 写真のどこを見せるかを変えている。拡大・縮小は GPU がやるので、
/// ライブビュー（毎秒30枚ほど）でも CPU で画像を作り直さずに済む。
///
/// 内カメの試験中の方式のうち、
/// - 人物・顔・注目度を使うもの（`Setting.analysisNeeds`）は、Vision の解析を別のスレッドで行い、
///   結果が出たら短冊を組み直す（ライブビューでは前の結果となめらかにつなぐ）
/// - 1枚の画像として作るもの（`Setting.needsPrerender`）は、別のスレッドで作った画像を1枚だけ出す
/// どちらも、前の仕事が終わっていなければそのコマは飛ばす（遅れを溜めない）。
final class LensView: UIView {

    /// かけるレンズ（方式と強さ）。変わったら短冊を組み直す。
    var setting: RotashLens.Setting = .plain {
        didSet {
            guard oldValue != setting else { return }
            analysis = nil
            analyzedImage = nil
            prerendered = nil
            prerenderedKey = nil
            setNeedsLayout()
        }
    }

    /// ライブビューか。ライブビューでは毎コマ解析し直し、写真では1回だけ解析する。
    var isLive = false

    private var image: CGImage?
    private var bandLayers: [CALayer] = []

    /// Vision の解析結果と、それを求めた画像。
    private var analysis: LensAnalysis?
    private var analyzedImage: CGImage?
    /// 1枚の画像として作った絵と、作ったときの画像・大きさ。
    private var prerendered: CGImage?
    private var prerenderedKey: (image: CGImage, size: CGSize)?

    /// 解析・組み立てを画面のスレッドの外でやる。前の仕事が終わるまで次は受けない（`isWorking`）。
    private let workQueue = DispatchQueue(label: "com.rotash.lens.work", qos: .userInitiated)
    private var isWorking = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .black
        // 枠のタップ（選択・撮影）は SwiftUI 側で受ける。ここでは触れても何もしない。
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 表示する画像を差し替える。ライブビューでは毎フレーム呼ばれる。
    func display(_ newImage: CGImage?) {
        let sizeChanged = newImage?.width != image?.width || newImage?.height != image?.height
        image = newImage

        if let newImage {
            if setting.needsPrerender {
                requestPrerender(newImage)
            } else if !setting.analysisNeeds.isEmpty, isLive || analyzedImage !== newImage {
                requestAnalysis(newImage)
            }
        }

        if sizeChanged || (setting.needsPrerender && prerendered == nil) {
            // 画像の縦横比が変わると短冊の割り方も変わるので、すぐ組み直す。
            setNeedsLayout()
            layoutIfNeeded()
            return
        }
        // 1枚の画像として作る方式は、作り終わった絵だけを出す（届いたコマをそのまま出すとちらつく）。
        guard !(setting.needsPrerender && prerendered != nil) else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in bandLayers { layer.contents = newImage }
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if setting.needsPrerender, let image, prerenderedKey?.size != bounds.size {
            requestPrerender(image)
        }
        rebuildBands()
    }

    // MARK: - 別スレッドの仕事

    private func requestAnalysis(_ target: CGImage) {
        guard !isWorking else { return }
        isWorking = true
        let needs = setting.analysisNeeds
        let requested = setting
        let live = isLive
        workQueue.async { [weak self] in
            let result = LensAnalyzer.analyze(target, needs: needs, live: live)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                guard self.setting == requested else { return self.restartWork() }
                self.analysis = live ? result.blended(from: self.analysis) : result
                self.analyzedImage = target
                self.setNeedsLayout()
            }
        }
    }

    private func requestPrerender(_ target: CGImage) {
        let size = bounds.size
        guard !isWorking, size.width > 0, size.height > 0 else { return }
        // 写真は同じ画像・同じ大きさなら作り直さない。
        if !isLive, let key = prerenderedKey, key.image === target, key.size == size { return }
        isWorking = true
        let requested = setting
        let live = isLive
        let scale = traitCollection.displayScale
        workQueue.async { [weak self] in
            let result = RotashLens.prerender(target, size: size, scale: scale, setting: requested, live: live)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                guard self.setting == requested else { return self.restartWork() }
                self.prerendered = result
                self.prerenderedKey = (target, size)
                self.setNeedsLayout()
            }
        }
    }

    /// 仕事の途中で方式が変わったとき、いまの方式でやり直す（写真は次のコマが来ないので、待っていても始まらない）。
    private func restartWork() {
        guard let image else { return }
        if setting.needsPrerender {
            requestPrerender(image)
        } else if !setting.analysisNeeds.isEmpty, analyzedImage !== image {
            requestAnalysis(image)
        }
    }

    // MARK: - 短冊

    private func rebuildBands() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        guard let image else {
            bandLayers.forEach { $0.removeFromSuperlayer() }
            bandLayers.removeAll()
            return
        }

        let contents: CGImage
        let bands: [RotashLens.Band]
        if setting.needsPrerender, let prerendered, prerenderedKey?.size == bounds.size {
            // 作った絵は枠いっぱい（上下の黒も含む）。
            contents = prerendered
            bands = [RotashLens.Band(destination: bounds,
                                     source: CGRect(x: 0, y: 0, width: 1, height: 1))]
        } else {
            contents = image
            bands = RotashLens.bands(imageSize: CGSize(width: image.width, height: image.height),
                                     in: bounds.size,
                                     setting: setting,
                                     pixelScale: traitCollection.displayScale,
                                     analysis: analysis)
        }

        while bandLayers.count > bands.count {
            bandLayers.removeLast().removeFromSuperlayer()
        }
        while bandLayers.count < bands.count {
            let layer = CALayer()
            layer.contentsGravity = .resize
            layer.minificationFilter = .linear
            layer.magnificationFilter = .linear
            self.layer.addSublayer(layer)
            bandLayers.append(layer)
        }

        for (layer, band) in zip(bandLayers, bands) {
            layer.frame = band.destination
            layer.contentsRect = band.source
            layer.contents = contents
        }
    }
}

/// 保存済みの写真に Rotash レンズをかけて表示する。
struct LensPhotoView: UIViewRepresentable {
    let image: CGImage
    let setting: RotashLens.Setting

    func makeUIView(context: Context) -> LensView {
        let view = LensView()
        view.setting = setting
        view.display(image)
        return view
    }

    func updateUIView(_ uiView: LensView, context: Context) {
        uiView.setting = setting
        uiView.display(image)
    }
}

/// Rotash レンズをかけたライブビュー。
/// 普通のプレビュー（`CameraPreview`）の代わりに、カメラの映像を1コマずつ受け取って表示する。
struct LensCameraPreview: UIViewRepresentable {
    let controller: CameraController
    let setting: RotashLens.Setting

    func makeUIView(context: Context) -> LensView {
        let view = LensView()
        view.isLive = true
        view.setting = setting
        controller.lensView = view
        return view
    }

    func updateUIView(_ uiView: LensView, context: Context) {
        uiView.setting = setting
        if controller.lensView !== uiView {
            controller.lensView = uiView
        }
    }

    /// SwiftUI がこの表示を捨てるとき、カメラからの映像の送り先から外す。
    /// （別の表示に作り直された直後に、古い表示へ映像を送り続けないように）
    static func dismantleUIView(_ uiView: LensView, coordinator: Coordinator) {
        coordinator.controller.detachLensView(uiView)
        uiView.display(nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    final class Coordinator {
        let controller: CameraController
        init(controller: CameraController) { self.controller = controller }
    }
}
