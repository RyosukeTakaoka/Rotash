import CoreGraphics
import CoreVideo

/// 上下または左右に動かしながら撮ったコマを、1枚のパノラマにつなぐ（試験中）。
///
/// # なぜ上下にも振れるようにしたか
///
/// 縦持ちの内カメで足りないのは「高さ」。横はもともと余っている。
/// 上下に振ってつなげば高さが増えるので、上下の黒も曲げも無しで縮めて、横を広く入れられる。
/// 左右に振れば、横がさらに広い写真になる。どちらに振ったかは、つないだずれの大きさで自動で決める。
///
/// # 手順
///
/// 1. コマごとに Vision の人物の切り抜きで「人」を見つけ、人ではない所（背景）だけで、
///    となりのコマとのずれを求める。自撮りでは人はいつも画面の同じ所にいるので、人を入れると
///    「ずれていない」と間違える
///    - 小さくした画像の明るさの変わり目を、列ごと・行ごとに平均した1次元の形でおおまかに合わせ
///    - 2次元の差で ±3px だけ詰め、放物線で 1px より細かく寄せる（つなぐほど誤差が積もるので）
/// 2. 重なる所の明るさの比から、コマごとの明るさをそろえる（そろえないと空に横じまが出る）
/// 3. 背景は、人を除いたコマを、ふちをぼかしながら重ねて平均する
/// 4. 人は、真ん中のコマから1回だけ重ねる（何コマも重ねると人が何人にも見える）
/// 5. どのコマでも人に隠れていた所（上下に振ったときの体のうしろなど）は、
///    多すぎる端は切り落とし、少しだけ残ったら上下のとなりの色で埋める
///
/// 重いので、画面のスレッドでは呼ばないこと。
enum PanoramaStitcher {

    /// 大まかに合わせるときの画像の幅と、詰めるときの幅。
    private static let coarseWidth = 160
    private static let fineWidth = 320
    /// コマのふちを、どれだけの幅でぼかして重ねるか（px）。
    private static let feather: Float = 48
    /// 動かした向きに、1コマの何倍まで広げるか（それより先は切る）。広すぎると枠では使い切れない。
    static let maxSpan: CGFloat = 2.0

    static func stitch(_ input: [CGImage]) -> CGImage? {
        guard let first = input.first else { return nil }
        let frameWidth = first.width, frameHeight = first.height
        let frames = input.filter { $0.width == frameWidth && $0.height == frameHeight }
        guard frames.count >= 3 else { return nil }
        let count = frames.count

        // ---- 1. 人の切り抜きと、ずれ
        let masks = frames.map { frame -> MaskGrid? in
            LensAnalyzer.personMask(frame, live: true).map(MaskGrid.init(buffer:))
        }
        // 太らせた人の所は何度も使うので、先に1回だけ求めておく。
        let grownMasks = masks.map { $0?.grown }
        var offsets: [(x: CGFloat, y: CGFloat)] = [(0, 0)]
        var gains: [CGFloat] = [1]
        var previous: Level?
        for index in 0..<count {
            guard let current = Level(frame: frames[index], grown: grownMasks[index]) else { return nil }
            if let previous {
                let coarseX = match(previous.columns, current.columns, maxShift: coarseWidth / 3)
                let coarseY = match(previous.rows, current.rows, maxShift: coarseWidth / 3)
                let fine = refine(previous, current, dx: coarseX * fineWidth / coarseWidth,
                                  dy: coarseY * fineWidth / coarseWidth, radius: 3)
                let toFrame = CGFloat(frameWidth) / CGFloat(fineWidth)
                let last = offsets[offsets.count - 1]
                offsets.append((last.x + fine.x * toFrame, last.y + fine.y * toFrame))
                gains.append(gains[gains.count - 1] * brightnessRatio(previous, current, dx: fine.x, dy: fine.y))
            }
            previous = current
        }

        // ---- 並べる範囲
        let reference = count / 2
        let xs = offsets.map { $0.x }, ys = offsets.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        let vertical = (maxY - minY) >= (maxX - minX)
        var left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat
        if vertical {
            // 横は全部のコマが重なる所だけ、縦は広げる（1コマの maxSpan 倍まで）。
            left = maxX; right = minX + CGFloat(frameWidth)
            let middle = ys[reference] + CGFloat(frameHeight) / 2, half = maxSpan * CGFloat(frameHeight) / 2
            top = max(minY, middle - half); bottom = min(maxY + CGFloat(frameHeight), middle + half)
        } else {
            top = maxY; bottom = minY + CGFloat(frameHeight)
            let middle = xs[reference] + CGFloat(frameWidth) / 2, half = maxSpan * CGFloat(frameWidth) / 2
            left = max(minX, middle - half); right = min(maxX + CGFloat(frameWidth), middle + half)
        }
        let width = Int((right - left).rounded(.down)), height = Int((bottom - top).rounded(.down))
        guard width >= frameWidth / 2, height >= frameHeight / 2 else { return nil }

        // ---- 3. 背景を重ねる
        let base = gains[reference]
        var accumulated = [Float](repeating: 0, count: width * height * 3)
        var weights = [Float](repeating: 0, count: width * height)
        for index in 0..<count {
            guard let pixels = rgba(frames[index]) else { continue }
            let originX = Int((xs[index] - left).rounded()), originY = Int((ys[index] - top).rounded())
            let gain = Float(gains[index] / base)
            let grown = grownMasks[index]
            let x0 = max(0, originX), x1 = min(width, originX + frameWidth)
            let y0 = max(0, originY), y1 = min(height, originY + frameHeight)
            guard x1 > x0, y1 > y0 else { continue }
            for y in y0..<y1 {
                let fy = y - originY
                let edgeY = Float(min(fy + 1, frameHeight - fy))
                for x in x0..<x1 {
                    let fx = x - originX
                    if let grown, grown.isPerson(x: fx, y: fy, frameWidth: frameWidth, frameHeight: frameHeight) {
                        continue
                    }
                    let edge = min(Float(min(fx + 1, frameWidth - fx)), edgeY)
                    let weight = min(1, max(0.02, edge / feather))
                    let source = (fy * frameWidth + fx) * 4
                    let target = y * width + x
                    accumulated[target * 3] += Float(pixels[source]) * gain * weight
                    accumulated[target * 3 + 1] += Float(pixels[source + 1]) * gain * weight
                    accumulated[target * 3 + 2] += Float(pixels[source + 2]) * gain * weight
                    weights[target] += weight
                }
            }
        }
        var canvas = [Float](repeating: 0, count: width * height * 3)
        var filled = [Bool](repeating: false, count: width * height)
        for index in 0..<(width * height) where weights[index] > 0.001 {
            canvas[index * 3] = accumulated[index * 3] / weights[index]
            canvas[index * 3 + 1] = accumulated[index * 3 + 1] / weights[index]
            canvas[index * 3 + 2] = accumulated[index * 3 + 2] / weights[index]
            filled[index] = true
        }
        accumulated = []

        // ---- 4. 人は真ん中のコマから
        let referenceX = Int((xs[reference] - left).rounded()), referenceY = Int((ys[reference] - top).rounded())
        let personRows = max(0, referenceY)..<max(max(0, referenceY), min(height, referenceY + frameHeight))
        let personColumns = max(0, referenceX)..<max(max(0, referenceX), min(width, referenceX + frameWidth))
        if let pixels = rgba(frames[reference]), let mask = masks[reference] {
            for y in personRows {
                let fy = y - referenceY
                for x in personColumns {
                    let fx = x - referenceX
                    let alpha = mask.value(x: fx, y: fy, frameWidth: frameWidth, frameHeight: frameHeight)
                    guard alpha > 0.01 else { continue }
                    let source = (fy * frameWidth + fx) * 4
                    let target = y * width + x
                    for channel in 0..<3 {
                        let value = Float(pixels[source + channel])
                        canvas[target * 3 + channel] = canvas[target * 3 + channel] * (1 - alpha) + value * alpha
                    }
                    if alpha > 0.5 { filled[target] = true }
                }
            }
        }

        // ---- 5. 抜けの多い端を切り落とす（人のいるコマの範囲までは切らない）
        var start = 0, end = vertical ? height : width
        let keepStart = vertical ? referenceY : referenceX
        let keepEnd = vertical ? referenceY + frameHeight : referenceX + frameWidth
        func fillRatio(_ line: Int) -> Float {
            var hits = 0
            let length = vertical ? width : height
            for i in 0..<length where filled[vertical ? line * width + i : i * width + line] { hits += 1 }
            return Float(hits) / Float(max(1, length))
        }
        while start < keepStart, start < end - 1, fillRatio(start) < 0.98 { start += 1 }
        while end > keepEnd, end - 1 > start, fillRatio(end - 1) < 0.98 { end -= 1 }

        let outX = vertical ? 0 : start, outY = vertical ? start : 0
        let outWidth = vertical ? width : end - start, outHeight = vertical ? end - start : height
        guard outWidth > 0, outHeight > 0 else { return nil }

        // 残った抜けは、上（なければ下）のとなりの色で埋める。
        for y in 0..<height {
            for x in 0..<width where !filled[y * width + x] && y > 0 && filled[(y - 1) * width + x] {
                for channel in 0..<3 { canvas[(y * width + x) * 3 + channel] = canvas[((y - 1) * width + x) * 3 + channel] }
                filled[y * width + x] = true
            }
        }
        for y in stride(from: height - 2, through: 0, by: -1) {
            for x in 0..<width where !filled[y * width + x] && filled[(y + 1) * width + x] {
                for channel in 0..<3 { canvas[(y * width + x) * 3 + channel] = canvas[((y + 1) * width + x) * 3 + channel] }
                filled[y * width + x] = true
            }
        }

        return makeImage(canvas, width: width, crop: (outX, outY, outWidth, outHeight))
    }

    // MARK: - ずれを求める

    /// 1コマを、ずれを求めやすい形にしたもの。
    private struct Level {
        /// 粗い幅での、列ごと・行ごとの明るさの変わり目の平均（人の所は除く。人ばかりの列は nil）。
        let columns: [Float?]
        let rows: [Float?]
        /// 細かい幅での、明るさと、明るさの変わり目、人ではない所。
        let gray: [Float]
        let gradient: [Float]
        let valid: [Bool]
        let width: Int
        let height: Int

        /// - Parameter grown: 太らせた人の切り抜き（無ければ全部を背景として使う）。
        init?(frame: CGImage, grown: MaskGrid?) {
            let coarseWidth = PanoramaStitcher.coarseWidth, fineWidth = PanoramaStitcher.fineWidth
            let coarseHeight = max(8, Int((CGFloat(frame.height) * CGFloat(coarseWidth) / CGFloat(frame.width)).rounded()))
            let fineHeight = max(8, Int((CGFloat(frame.height) * CGFloat(fineWidth) / CGFloat(frame.width)).rounded()))
            guard let coarse = PanoramaStitcher.gray(frame, width: coarseWidth, height: coarseHeight),
                  let fine = PanoramaStitcher.gray(frame, width: fineWidth, height: fineHeight)
            else { return nil }

            func validity(width: Int, height: Int) -> [Bool] {
                var result = [Bool](repeating: true, count: width * height)
                guard let grown else { return result }
                for y in 0..<height {
                    for x in 0..<width where grown.isPerson(x: x, y: y, frameWidth: width, frameHeight: height) {
                        result[y * width + x] = false
                    }
                }
                return result
            }

            let coarseValid = validity(width: coarseWidth, height: coarseHeight)
            let coarseGradient = PanoramaStitcher.gradients(coarse, width: coarseWidth, height: coarseHeight)
            var columns: [Float?] = []
            for x in 0..<coarseWidth {
                var sum: Float = 0, samples = 0
                for y in 0..<coarseHeight where coarseValid[y * coarseWidth + x] {
                    sum += coarseGradient.x[y * coarseWidth + x]; samples += 1
                }
                columns.append(samples > 3 ? sum / Float(samples) : nil)
            }
            var rows: [Float?] = []
            for y in 0..<coarseHeight {
                var sum: Float = 0, samples = 0
                for x in 0..<coarseWidth where coarseValid[y * coarseWidth + x] {
                    sum += coarseGradient.y[y * coarseWidth + x]; samples += 1
                }
                rows.append(samples > 3 ? sum / Float(samples) : nil)
            }
            self.columns = columns
            self.rows = rows

            let fineGradient = PanoramaStitcher.gradients(fine, width: fineWidth, height: fineHeight)
            gray = fine
            gradient = zip(fineGradient.x, fineGradient.y).map { $0 + $1 }
            valid = validity(width: fineWidth, height: fineHeight)
            width = fineWidth
            height = fineHeight
        }
    }

    /// current[i] = previous[i + d] になる d（1次元の形どうしを、ずらしながら比べる）。
    private static func match(_ previous: [Float?], _ current: [Float?], maxShift: Int) -> Int {
        let length = min(previous.count, current.count)
        var best = Float.infinity, bestShift = 0
        for shift in -maxShift...maxShift {
            let low = max(0, -shift), high = min(length, length - shift)
            guard high - low >= length / 3 else { continue }
            var sum: Float = 0, samples = 0
            for i in low..<high {
                guard let a = current[i], let b = previous[i + shift] else { continue }
                sum += abs(a - b); samples += 1
            }
            guard samples >= length / 4 else { continue }
            let score = sum / Float(samples)
            if score < best { best = score; bestShift = shift }
        }
        return bestShift
    }

    /// 細かい幅で ±radius だけ2次元で詰め、放物線で 1px より細かく寄せる。
    private static func refine(_ previous: Level, _ current: Level, dx: Int, dy: Int, radius: Int) -> (x: CGFloat, y: CGFloat) {
        let width = current.width, height = current.height
        var costs: [Int: Float] = [:]
        func key(_ x: Int, _ y: Int) -> Int { (y + 10_000) * 100_000 + (x + 10_000) }
        var best = Float.infinity, bestX = dx, bestY = dy
        for shiftY in (dy - radius)...(dy + radius) {
            for shiftX in (dx - radius)...(dx + radius) {
                let y0 = max(0, -shiftY), y1 = min(height, height - shiftY)
                let x0 = max(0, -shiftX), x1 = min(width, width - shiftX)
                guard y1 - y0 >= height / 3, x1 - x0 >= width / 3 else { continue }
                var sum: Float = 0, samples = 0
                // 1行おき・1列おきに比べる（十分に正確で、4倍速い）。
                for y in stride(from: y0, to: y1, by: 2) {
                    let row = y * width, previousRow = (y + shiftY) * width + shiftX
                    for x in stride(from: x0, to: x1, by: 2)
                    where current.valid[row + x] && previous.valid[previousRow + x] {
                        sum += abs(current.gradient[row + x] - previous.gradient[previousRow + x])
                        samples += 1
                    }
                }
                guard samples >= 200 else { continue }
                let score = sum / Float(samples)
                costs[key(shiftX, shiftY)] = score
                if score < best { best = score; bestX = shiftX; bestY = shiftY }
            }
        }
        func vertex(_ minus: Float?, _ plus: Float?) -> CGFloat {
            guard let minus, let plus else { return 0 }
            let denominator = minus - 2 * best + plus
            guard denominator > 1e-9 else { return 0 }
            return CGFloat(max(-0.5, min(0.5, 0.5 * (minus - plus) / denominator)))
        }
        return (CGFloat(bestX) + vertex(costs[key(bestX - 1, bestY)], costs[key(bestX + 1, bestY)]),
                CGFloat(bestY) + vertex(costs[key(bestX, bestY - 1)], costs[key(bestX, bestY + 1)]))
    }

    /// 重なる所の明るさの比（前のコマ ÷ このコマ）。このコマに掛けると前のコマとそろう。
    private static func brightnessRatio(_ previous: Level, _ current: Level, dx: CGFloat, dy: CGFloat) -> CGFloat {
        let shiftX = Int(dx.rounded()), shiftY = Int(dy.rounded())
        let width = current.width, height = current.height
        var a: Float = 0, b: Float = 0
        for y in stride(from: max(0, -shiftY), to: min(height, height - shiftY), by: 2) {
            for x in stride(from: max(0, -shiftX), to: min(width, width - shiftX), by: 2) {
                let here = y * width + x, there = (y + shiftY) * width + x + shiftX
                guard current.valid[here], previous.valid[there] else { continue }
                a += previous.gray[there]; b += current.gray[here]
            }
        }
        guard a > 0, b > 0 else { return 1 }
        return CGFloat(min(1.5, max(0.67, a / b)))
    }

    // MARK: - 画素

    /// 灰色に小さくした画像（0〜255）。
    private static func gray(_ image: CGImage, width: Int, height: Int) -> [Float]? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height)
        return (0..<(width * height)).map { Float(bytes[$0]) }
    }

    private static func gradients(_ gray: [Float], width: Int, height: Int) -> (x: [Float], y: [Float]) {
        var gx = [Float](repeating: 0, count: width * height), gy = gx
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                if x > 0, x < width - 1 { gx[index] = abs(gray[index + 1] - gray[index - 1]) }
                if y > 0, y < height - 1 { gy[index] = abs(gray[index + width] - gray[index - width]) }
            }
        }
        return (gx, gy)
    }

    /// 画素の並び（R, G, B, A の順。行 0 が画像の上）。
    private static func rgba(_ image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                        | CGBitmapInfo.byteOrder32Big.rawValue),
              let data = context.data
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Array(UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: width * height * 4),
                                         count: width * height * 4))
    }

    private static func makeImage(_ canvas: [Float], width: Int,
                                  crop: (x: Int, y: Int, width: Int, height: Int)) -> CGImage? {
        guard let context = CGContext(data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8,
                                      bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                                        | CGBitmapInfo.byteOrder32Big.rawValue),
              let data = context.data
        else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: crop.width * crop.height * 4)
        for y in 0..<crop.height {
            for x in 0..<crop.width {
                let source = ((y + crop.y) * width + x + crop.x) * 3
                let target = (y * crop.width + x) * 4
                bytes[target] = UInt8(min(255, max(0, canvas[source])))
                bytes[target + 1] = UInt8(min(255, max(0, canvas[source + 1])))
                bytes[target + 2] = UInt8(min(255, max(0, canvas[source + 2])))
                bytes[target + 3] = 255
            }
        }
        return context.makeImage()
    }
}

/// Vision の人物の切り抜き（マスク）を、配列に写したもの。
/// Vision の画素の入れ物は使い回されることがあるので、すぐに写しておく。
struct MaskGrid {
    let width: Int
    let height: Int
    /// 0〜1。1 が人。
    let values: [Float]

    init(buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        var values = [Float](repeating: 0, count: width * height)
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let pixels = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width { values[y * width + x] = Float(pixels[y * bytesPerRow + x]) / 255 }
            }
        }
        self.init(width: width, height: height, values: values)
    }

    init(width: Int, height: Int, values: [Float]) {
        self.width = width
        self.height = height
        self.values = values
    }

    /// 人の所を少し太らせたもの（ふちの取り残しで、背景に人の影が残らないように）。
    var grown: MaskGrid {
        let radius = max(1, width / 60)
        // 横に太らせてから縦に太らせる（四角い範囲の最大値）。
        var horizontal = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var peak: Float = 0
                for dx in max(0, x - radius)...min(width - 1, x + radius) { peak = max(peak, values[y * width + dx]) }
                horizontal[y * width + x] = peak
            }
        }
        var result = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var peak: Float = 0
                for dy in max(0, y - radius)...min(height - 1, y + radius) { peak = max(peak, horizontal[dy * width + x]) }
                result[y * width + x] = peak
            }
        }
        return MaskGrid(width: width, height: height, values: result)
    }

    /// コマの (x, y)（コマの大きさ frameWidth × frameHeight の中の位置）の値。近い画素を使う。
    func value(x: Int, y: Int, frameWidth: Int, frameHeight: Int) -> Float {
        guard width > 0, height > 0 else { return 0 }
        let mx = min(width - 1, max(0, x * width / max(1, frameWidth)))
        let my = min(height - 1, max(0, y * height / max(1, frameHeight)))
        return values[my * width + mx]
    }

    func isPerson(x: Int, y: Int, frameWidth: Int, frameHeight: Int) -> Bool {
        value(x: x, y: y, frameWidth: frameWidth, frameHeight: frameHeight) > 0.08
    }
}
