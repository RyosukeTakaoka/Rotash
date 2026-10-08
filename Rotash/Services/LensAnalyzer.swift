import CoreGraphics
import CoreVideo
import Vision

/// 写真（またはライブビューの1コマ）の「どこに人がいるか」を、横の位置ごとにまとめたもの。
///
/// どの値も、写真の横幅を `bins` 等分したそれぞれの列について 0〜1 で持つ。
/// 列ごとの値にしておくと、ライブビューで前のコマとなめらかにつなぐ（`blended`）のが簡単になる。
struct LensAnalysis: Equatable {
    static let bins = 128

    /// 人物の切り抜き（マスク）が、その列の高さのうち何割を占めるか。
    var person: [CGFloat]?
    /// 顔（少し余白を足した範囲）がかかっている列は 1、そうでない列は 0。
    var face: [CGFloat]?
    /// 注目度（人が見そうな所）の、その列でいちばん高い値。いちばん高い列を 1 にそろえる。
    var saliency: [CGFloat]?

    /// 人物の横の中心（写真の横幅を 1 とした位置）。人が見つからなければ nil。
    var personCenter: CGFloat? {
        guard let person else { return nil }
        let total = person.reduce(0, +)
        guard total > 0.05 else { return nil }
        let weighted = person.indices.reduce(CGFloat(0)) { $0 + (CGFloat($1) + 0.5) * person[$1] }
        return weighted / total / CGFloat(person.count)
    }

    /// ライブビューで、前の解析結果となめらかにつなぐ（毎回ぱっと変わると、背景がガタガタ揺れる）。
    func blended(from previous: LensAnalysis?, amount: CGFloat = 0.4) -> LensAnalysis {
        guard let previous else { return self }
        func mix(_ new: [CGFloat]?, _ old: [CGFloat]?) -> [CGFloat]? {
            guard let new else { return nil }
            guard let old, old.count == new.count else { return new }
            return new.indices.map { old[$0] + (new[$0] - old[$0]) * amount }
        }
        return LensAnalysis(person: mix(person, previous.person),
                            face: mix(face, previous.face),
                            saliency: mix(saliency, previous.saliency))
    }
}

/// Vision で、人物・顔・注目度を調べる。どれも重いので、画面のスレッドでは呼ばないこと。
enum LensAnalyzer {

    /// 何を調べるか。
    struct Needs: OptionSet {
        let rawValue: Int
        static let person = Needs(rawValue: 1 << 0)
        static let face = Needs(rawValue: 1 << 1)
        static let saliency = Needs(rawValue: 1 << 2)
    }

    /// - Parameter live: ライブビュー用（人物の切り抜きを速い設定にする）。
    static func analyze(_ image: CGImage, needs: Needs, live: Bool) -> LensAnalysis {
        var result = LensAnalysis()
        guard !needs.isEmpty else { return result }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let personRequest = VNGeneratePersonSegmentationRequest()
        personRequest.qualityLevel = live ? .fast : .balanced
        personRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let faceRequest = VNDetectFaceRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        var requests: [VNRequest] = []
        if needs.contains(.person) { requests.append(personRequest) }
        if needs.contains(.face) { requests.append(faceRequest) }
        if needs.contains(.saliency) { requests.append(saliencyRequest) }

        do {
            try handler.perform(requests)
        } catch {
            #if DEBUG
            print("🔍 レンズの解析に失敗:", error)
            #endif
            return result
        }

        if needs.contains(.person), let mask = personRequest.results?.first?.pixelBuffer {
            result.person = columns(ofMask: mask)
        }
        if needs.contains(.face) {
            result.face = faceColumns(faceRequest.results ?? [])
        }
        if needs.contains(.saliency), let heatmap = saliencyRequest.results?.first?.pixelBuffer {
            result.saliency = columns(ofHeatmap: heatmap)
        }
        return result
    }

    /// 人物の切り抜き（マスク）。白い所が人。
    /// - Parameter live: ライブビュー用（速い設定）。写真の表示・共有画像ではきれいな設定にする。
    static func personMask(_ image: CGImage, live: Bool) -> CVPixelBuffer? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = live ? .balanced : .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            return nil
        }
        return request.results?.first?.pixelBuffer
    }

    /// マスクの各列で、人が高さの何割を占めるか。
    static func columns(ofMask mask: CVPixelBuffer) -> [CGFloat] {
        let bins = LensAnalysis.bins
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return [] }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        guard width > 0, height > 0 else { return [] }
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        var hits = [Int](repeating: 0, count: bins)
        var samples = [Int](repeating: 0, count: bins)
        for x in 0..<width {
            let bin = min(bins - 1, x * bins / width)
            for y in stride(from: 0, to: height, by: 2) {
                if pixels[y * bytesPerRow + x] > 127 { hits[bin] += 1 }
                samples[bin] += 1
            }
        }
        return (0..<bins).map { samples[$0] > 0 ? CGFloat(hits[$0]) / CGFloat(samples[$0]) : 0 }
    }

    /// 顔のある列を 1 にする。顔の幅の 20% ずつ余白を足して、耳や髪まで守る。
    static func faceColumns(_ faces: [VNFaceObservation]) -> [CGFloat] {
        let bins = LensAnalysis.bins
        var result = [CGFloat](repeating: 0, count: bins)
        for face in faces {
            // boundingBox は 0〜1 の割合。横の向きは画像と同じ（左が 0）。
            let box = face.boundingBox
            let margin = box.width * 0.2
            let start = max(0, Int(((box.minX - margin) * CGFloat(bins)).rounded(.down)))
            let end = min(bins - 1, Int(((box.maxX + margin) * CGFloat(bins)).rounded(.up)))
            guard start <= end else { continue }
            for index in start...end { result[index] = 1 }
        }
        return result
    }

    /// 注目度の地図（小さな 32bit 小数の画像）の各列の最大値。いちばん高い列を 1 にそろえる。
    static func columns(ofHeatmap heatmap: CVPixelBuffer) -> [CGFloat] {
        let bins = LensAnalysis.bins
        CVPixelBufferLockBaseAddress(heatmap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(heatmap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(heatmap),
              CVPixelBufferGetPixelFormatType(heatmap) == kCVPixelFormatType_OneComponent32Float
        else { return [] }
        let width = CVPixelBufferGetWidth(heatmap)
        let height = CVPixelBufferGetHeight(heatmap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(heatmap)
        guard width > 0, height > 0 else { return [] }

        var columnMax = [Float](repeating: 0, count: width)
        for y in 0..<height {
            let row = (base + y * bytesPerRow).assumingMemoryBound(to: Float.self)
            for x in 0..<width { columnMax[x] = max(columnMax[x], row[x]) }
        }
        let peak = max(columnMax.max() ?? 0, 0.0001)
        return (0..<bins).map { (index: Int) -> CGFloat in
            let x = min(width - 1, index * width / bins)
            return CGFloat(columnMax[x] / peak)
        }
    }
}
