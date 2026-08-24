import SwiftUI
import UIKit

/// 保存済みの写真を枠いっぱいに表示する。写真が主役なので余計な装飾はつけない。
struct PhotoImageView: View {
    let filename: String
    var maxPixel: CGFloat?

    @State private var image: UIImage?

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
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            }
        }
        .clipped()
        .task(id: filename) { await load() }
    }

    private func load() async {
        let name = filename
        let pixel = maxPixel
        let loaded: UIImage? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: PhotoStore.shared.image(for: name, maxPixel: pixel))
            }
        }
        image = loaded
    }
}
