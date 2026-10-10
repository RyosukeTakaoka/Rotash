import SwiftUI
import UIKit

/// 保存済みの写真を枠いっぱいに表示する。写真が主役なので余計な装飾はつけない。
///
/// 手元にあればローカルから、無ければ URL から取ってきてキャッシュする。
/// 他の人が撮った写真をまだ落としていない状態でも、そのまま置いておけば表示される。
struct PhotoImageView: View {
    var filename: String?
    var remoteURL: String?
    var maxPixel: CGFloat?
    /// 枠いっぱいに広げず、写真そのものの縦横比で出すか（`natural()`）。
    private var keepsAspect = false
    /// 写真が読めたときに、その大きさを知らせる（`onLoad(_:)`）。
    private var loaded: ((CGSize) -> Void)?

    @State private var image: UIImage?

    init(filename: String?, remoteURL: String? = nil, maxPixel: CGFloat? = nil) {
        self.filename = filename
        self.remoteURL = remoteURL
        self.maxPixel = maxPixel
    }

    init(slot: Slot, maxPixel: CGFloat? = nil) {
        self.filename = slot.photoFilename
        self.remoteURL = slot.photoURL
        self.maxPixel = maxPixel
    }

    /// その日の裏の写真（撮るときにシャッター側の丸に映っていた方）。
    init(reverseOf slot: Slot, maxPixel: CGFloat? = nil) {
        self.filename = slot.reversePhotoFilename
        self.remoteURL = slot.reversePhotoURL
        self.maxPixel = maxPixel
    }

    var body: some View {
        if keepsAspect {
            naturalBody
        } else {
            filledBody
        }
    }

    /// 写真そのものの縦横比で、収まる大きさに出す。読めるまでは 4:3 の暗い枠。
    private var naturalBody: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Palette.surfaceDeep.aspectRatio(4.0 / 3.0, contentMode: .fit)
            }
        }
        .task(id: taskID) { await load() }
    }

    private var filledBody: some View {
        ZStack {
            Palette.surfaceDeep
            if let image {
                // aspectRatio(.fill) を Image に直接かけると、画像は提案サイズより
                // 大きく広がり、clipped() は描画だけを切ってレイアウトサイズは戻さない。
                // その結果「写真の入った枠だけ幅を余計に要求する」ことになり 1/7 が崩れる。
                // overlay の中身はレイアウトに影響しないので、この形なら常に枠ぴったりになる。
                Color.clear
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            }
        }
        .clipped()
        .task(id: taskID) { await load() }
    }

    /// 写真を切り抜かず、写真そのものの縦横比で出す（Memories や撮ったあとの確認で、全体を見せるため）。
    func natural() -> PhotoImageView {
        var copy = self
        copy.keepsAspect = true
        return copy
    }

    /// 写真が読めたら、その大きさ（向きを反映した後）を知らせる。
    func onLoad(_ action: @escaping (CGSize) -> Void) -> PhotoImageView {
        var copy = self
        copy.loaded = action
        return copy
    }

    private var taskID: String {
        "\(filename ?? "-")|\(remoteURL ?? "-")"
    }

    private func load() async {
        if let filename, let local = await loadLocal(filename) {
            show(local)
            return
        }
        guard let remoteURL,
              let data = try? await CloudinaryClient.download(from: remoteURL),
              let cached = try? PhotoStore.shared.save(data)
        else { return }
        show(await loadLocal(cached))
    }

    private func show(_ loadedImage: UIImage?) {
        image = loadedImage
        if let loadedImage { loaded?(loadedImage.size) }
    }

    private func loadLocal(_ name: String) async -> UIImage? {
        let pixel = maxPixel
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: PhotoStore.shared.image(for: name, maxPixel: pixel))
            }
        }
    }
}

/// 表と裏を持つカード。`flipped` が変わると、縦の軸でくるっと裏返る。
/// 枠の長押し（その日の裏）と、Memories の作品全体の裏返しで使う。
///
/// 裏は、はじめて裏返すまで作らない。見えない裏まで7枚ぶん読み込むと、
/// カメラを動かしている横持ちの画面でメモリを大きく使うため。
struct FlipCard<Front: View, Back: View>: View {
    var flipped: Bool
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back

    @State private var backBuilt = false

    var body: some View {
        ZStack {
            front()
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(flipped ? 0 : 1)
            if backBuilt || flipped {
                back()
                    .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .opacity(flipped ? 1 : 0)
            }
        }
        .onChange(of: flipped) { _, isFlipped in
            if isFlipped { backBuilt = true }
        }
    }
}
