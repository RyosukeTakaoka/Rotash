import AVFoundation
import SwiftUI

/// 7 分割の「担当枠の中だけ」に出るライブビュー。
/// 全画面プレビューは出さないので、撮る人は完成写真の全体を見ないまま撮ることになる。
struct CameraPreview: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = controller.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        controller.previewLayer = view.videoPreviewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== controller.session {
            uiView.videoPreviewLayer.session = controller.session
        }
        if controller.previewLayer !== uiView.videoPreviewLayer {
            controller.previewLayer = uiView.videoPreviewLayer
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - 表と裏を同時に撮るときの部品

/// 同時撮影で、カメラの映像をそのまま映すレイヤー（`CameraController.livePreviewLayer(for:)`）を置く View。
///
/// FLIP で表と裏を入れ替えると、同じレイヤーが大きい画面とシャッターの丸のあいだを行き来する
/// （レイヤーは1か所にしか置けないので、置き直した側が持っていく）。
struct LiveLayerView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.backgroundColor = .black
        // 押したのはシャッター（SwiftUI のボタン）として受けたいので、ここでは触れても何もしない。
        view.isUserInteractionEnabled = false
        view.host(layer, gravity: gravity)
        return view
    }

    func updateUIView(_ uiView: HostView, context: Context) {
        uiView.host(layer, gravity: gravity)
    }

    final class HostView: UIView {
        private weak var hosted: AVCaptureVideoPreviewLayer?

        func host(_ preview: AVCaptureVideoPreviewLayer, gravity: AVLayerVideoGravity) {
            if preview.superlayer !== layer {
                preview.removeFromSuperlayer()
                layer.addSublayer(preview)
            }
            hosted = preview
            preview.videoGravity = gravity
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // もう別の View に持っていかれたレイヤーは触らない（大きさを間違って上書きしないように）。
            guard let hosted, hosted.superlayer === layer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            CATransaction.commit()
        }
    }
}

/// シャッターボタンを、裏（もう一方のカメラ）が映る丸いカメラとして見せる。押すと表と裏を撮る。
///
/// 同時撮影できない端末では裏をライブで映せないので、ふつうの白い丸に戻す（押せば裏も続けて撮る）。
struct CameraShutter: View {
    @ObservedObject var camera: CameraController
    var diameter: CGFloat = 92
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if camera.isDual, camera.status == .ready,
                   let layer = camera.livePreviewLayer(for: camera.reversePosition) {
                    LiveLayerView(layer: layer)
                        .frame(width: diameter - 8, height: diameter - 8)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: diameter - 16, height: diameter - 16)
                }
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 3)
                    .frame(width: diameter, height: diameter)
            }
            .frame(width: diameter, height: diameter)
            .opacity(isBusy ? 0.35 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

/// 大きい画面に重ねる、「7分割の枠（サムネ）に入る範囲」の線。範囲の外は少し暗くする。
/// - Parameter region: 写真全体を 0〜1 とした、サムネに入る範囲（`centerCrop`）。
struct ThumbnailGuide: View {
    let region: CGRect

    /// 写真（縦横比 imageAspect = 幅 ÷ 高さ）を、枠（cellAspect）いっぱいに収めたとき（aspectFill）に
    /// 枠に入る範囲。写真の真ん中を枠の形に切り出した所になる。
    static func centerCrop(imageAspect: CGFloat, cellAspect: CGFloat) -> CGRect {
        guard imageAspect > 0, cellAspect > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        if cellAspect < imageAspect {
            let width = cellAspect / imageAspect
            return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
        }
        let height = imageAspect / cellAspect
        return CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let rect = CGRect(x: region.minX * size.width, y: region.minY * size.height,
                              width: region.width * size.width, height: region.height * size.height)
            ZStack(alignment: .topLeading) {
                // 外側だけを暗くする（内側をくり抜く）。
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRect(rect)
                }
                .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))

                Rectangle()
                    .stroke(Palette.live, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)

                Text("サムネ")
                    .rotashLabel(8, color: Palette.live, tracking: 1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .offset(x: rect.minX + 4, y: rect.minY + 4)
            }
        }
        .allowsHitTesting(false)
    }
}
