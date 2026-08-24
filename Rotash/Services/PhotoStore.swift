import UIKit
import ImageIO

/// 写真の実体（JPEG）をローカルに置く。state.json はファイル名だけを持つ。
final class PhotoStore {

    static let shared = PhotoStore()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        RotashPaths.prepareDirectories()
        cache.countLimit = 40
    }

    func url(for filename: String) -> URL {
        RotashPaths.photos.appendingPathComponent(filename)
    }

    func exists(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: filename).path)
    }

    @discardableResult
    func save(_ data: Data, filename: String = UUID().uuidString + ".jpg") throws -> String {
        try data.write(to: url(for: filename), options: .atomic)
        return filename
    }

    func data(for filename: String) -> Data? {
        try? Data(contentsOf: url(for: filename))
    }

    func delete(_ filename: String) {
        cache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    /// 表示用。maxPixel を指定すると縮小して読み込む（Memories の一覧用）。
    func image(for filename: String, maxPixel: CGFloat? = nil) -> UIImage? {
        let key = (filename + "@\(Int(maxPixel ?? 0))") as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let fileURL = url(for: filename)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }

        let image: UIImage?
        if let maxPixel {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel * max(UITraitCollection.current.displayScale, 2)
            ]
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                .map { UIImage(cgImage: $0) }
        } else {
            image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
                .map { UIImage(cgImage: $0, scale: 1, orientation: .up) }
        }

        if let image { cache.setObject(image, forKey: key) }
        return image
    }
}

extension UIImage {
    /// EXIF の向きを焼き込んで .up にした JPEG を返す。横長のまま保存する（縦への変換はしない）。
    func rotashJPEGData(quality: CGFloat = 0.92) -> Data? {
        if imageOrientation == .up { return jpegData(compressionQuality: quality) }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.jpegData(compressionQuality: quality)
    }
}
