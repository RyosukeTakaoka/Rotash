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
    /// 1 より大きいと Rotash レンズをかけて表示する（7分割の枠用）。
    var lensWidening: Double = 1

    @State private var image: UIImage?

    init(filename: String?, remoteURL: String? = nil, maxPixel: CGFloat? = nil) {
        self.filename = filename
        self.remoteURL = remoteURL
        self.maxPixel = maxPixel
    }

    init(slot: Slot, maxPixel: CGFloat? = nil, lensWidening: Double = 1) {
        self.filename = slot.photoFilename
        self.remoteURL = slot.photoURL
        self.maxPixel = maxPixel
        self.lensWidening = lensWidening
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
                        if lensWidening > 1, let cgImage = image.cgImage, image.imageOrientation == .up {
                            LensPhotoView(image: cgImage, widening: lensWidening)
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
