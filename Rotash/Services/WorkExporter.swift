import UIKit

/// 完成した作品を共有する。加工はしない。写真そのもの。
enum WorkExporter {

    /// Instagram のカルーセル用。その週の横長写真をそのまま書き出す。
    static func photoURLs(for week: RotashWeek) -> [URL] {
        let stamp = RotashDateFormat.fileStamp.string(from: week.startDate)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-\(stamp)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var urls: [URL] = []
        for (position, slot) in week.slots.sorted(by: { $0.dayIndex < $1.dayIndex }).enumerated() {
            guard let filename = slot.photoFilename,
                  let data = PhotoStore.shared.data(for: filename) else { continue }
            let name = "ROTASH-\(stamp)-\(position + 1)-\(RotashDay.label(for: slot.dayIndex)).jpg"
            let url = directory.appendingPathComponent(name)
            if (try? data.write(to: url, options: .atomic)) != nil {
                urls.append(url)
            }
        }
        return urls
    }

    /// 分割したまま 1 枚に並べたコンタクトシート（アプリ内で見えている作品と同じ見え方）。
    /// 週の途中で始めた初回は枚数が 7 未満になるので、枚数に合わせて割り付ける。
    static func contactSheetURL(for week: RotashWeek, height: CGFloat = 1080) -> URL? {
        let ordered = week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })
        let count = max(ordered.count, 1)
        let gap: CGFloat = 2
        let gapTotal = gap * CGFloat(count - 1)
        let panelWidth = ((height * 16 / 9) - gapTotal) / CGFloat(count)
        let totalWidth = panelWidth * CGFloat(count) + gapTotal
        let size = CGSize(width: totalWidth.rounded(), height: height)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for (position, slot) in ordered.enumerated() {
                let panel = CGRect(x: (panelWidth + gap) * CGFloat(position),
                                   y: 0,
                                   width: panelWidth,
                                   height: height)
                guard let filename = slot.photoFilename,
                      let photo = PhotoStore.shared.image(for: filename) else { continue }

                context.cgContext.saveGState()
                context.cgContext.clip(to: panel)
                photo.draw(in: aspectFillRect(imageSize: photo.size, in: panel))
                context.cgContext.restoreGState()
            }
        }

        guard let data = image.jpegData(compressionQuality: 0.94) else { return nil }
        let stamp = RotashDateFormat.fileStamp.string(from: week.startDate)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROTASH-\(stamp)-contactsheet.jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func aspectFillRect(imageSize: CGSize, in rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: rect.midX - drawSize.width / 2,
                      y: rect.midY - drawSize.height / 2,
                      width: drawSize.width,
                      height: drawSize.height)
    }
}
