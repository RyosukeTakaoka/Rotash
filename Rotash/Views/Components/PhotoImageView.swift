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
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
