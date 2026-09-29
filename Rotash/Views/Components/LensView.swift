import SwiftUI
import UIKit

/// `RotashLens` の短冊を、そのまま CALayer の並びとして表示する View。
///
/// 1枚の画像を短冊の数だけのレイヤーに共有させ、それぞれの `contentsRect` で
/// 写真のどこを見せるかを変えている。拡大・縮小は GPU がやるので、
/// ライブビュー（毎秒30枚ほど）でも CPU で画像を作り直さずに済む。
final class LensView: UIView {

    /// かけるレンズ（方式と強さ）。変わったら短冊を組み直す。
    var setting: RotashLens.Setting = .plain {
        didSet { if oldValue != setting { setNeedsLayout() } }
    }

    private var image: CGImage?
    private var bandLayers: [CALayer] = []

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

        if sizeChanged {
            // 画像の縦横比が変わると短冊の割り方も変わるので、すぐ組み直す。
            setNeedsLayout()
            layoutIfNeeded()
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in bandLayers { layer.contents = newImage }
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildBands()
    }

    private func rebuildBands() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        guard let image else {
            bandLayers.forEach { $0.removeFromSuperlayer() }
            bandLayers.removeAll()
            return
        }

        let scale = traitCollection.displayScale
        let bands = RotashLens.bands(imageSize: CGSize(width: image.width, height: image.height),
                                     in: bounds.size,
                                     setting: setting,
                                     pixelScale: scale)

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
            layer.contents = image
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
