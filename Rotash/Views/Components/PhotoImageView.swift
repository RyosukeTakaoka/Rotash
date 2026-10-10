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
    /// かける Rotash レンズ（7分割の枠用）。既定はかけない。
    var lens: RotashLens.Setting = .plain

    @State private var image: UIImage?

    init(filename: String?, remoteURL: String? = nil, maxPixel: CGFloat? = nil) {
        self.filename = filename
        self.remoteURL = remoteURL
        self.maxPixel = maxPixel
    }

    init(slot: Slot, maxPixel: CGFloat? = nil, lens: RotashLens.Setting = .plain) {
        self.filename = slot.photoFilename
        self.remoteURL = slot.photoURL
        self.maxPixel = maxPixel
        self.lens = lens
    }

    /// その日の裏の写真（撮るときにシャッター側の丸に映っていた方）。
    init(reverseOf slot: Slot, maxPixel: CGFloat? = nil, lens: RotashLens.Setting = .plain) {
        self.filename = slot.reversePhotoFilename
        self.remoteURL = slot.reversePhotoURL
        self.maxPixel = maxPixel
        self.lens = lens
    }

    var body: some View {
        ZStack {
            Palette.surfaceDeep
            if let image {
                // aspectRatio(.fill) を Image に直接かけると、画像は提案サイズより
                // 大きく広がり、clipped() は描画だけを切ってレイアウトサイズは戻さない。
                // その結果「写真の入った枠だけ幅を余計に要求する」ことになり 1/7 が崩れる。
                // overlay の中身はレイアウトに影響しないので、この形なら常に枠ぴったりになる。
                Color.clear
                    .overlay {
                        if lens.isActive, let cgImage = image.cgImage, image.imageOrientation == .up {
                            LensPhotoView(image: cgImage, setting: lens)
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipped()
            }
        }
        .clipped()
        .task(id: taskID) { await load() }
    }

    private var taskID: String {
        "\(filename ?? "-")|\(remoteURL ?? "-")"
    }

    private func load() async {
        if let filename, let local = await loadLocal(filename) {
            image = local
            return
        }
        guard let remoteURL,
              let data = try? await CloudinaryClient.download(from: remoteURL),
              let cached = try? PhotoStore.shared.save(data)
        else { return }
        image = await loadLocal(cached)
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
struct FlipCard<Front: View, Back: View>: View {
    var flipped: Bool
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back

    var body: some View {
        ZStack {
            front()
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(flipped ? 0 : 1)
            back()
                .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .opacity(flipped ? 1 : 0)
        }
    }
}
