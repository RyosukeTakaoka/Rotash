import CoreGraphics
import CoreImage
import CoreVideo

/// 短冊を並べるだけでは作れない内カメの方式を、1枚の画像として組み立てる（試験中）。
///
/// - `cutout`: 人を切り抜いて原寸のまま重ね、うしろの背景だけを均一に強く押し込む
/// - `seamCarved`: シームカービング。目立たない縦の継ぎ目を1本ずつ抜いて幅を詰める
///
/// どちらも上下の黒を含めた「枠いっぱいの画像」を返す。重いので、画面のスレッドでは呼ばないこと。
enum LensCompositor {

    /// Core Image の描画先。作るのが重いので使い回す（複数のスレッドから使ってよい）。
    private static let context = CIContext(options: [.cacheIntermediates: false])

    // MARK: - 人を切り抜いて重ねる

    /// 背景: 枠に入れる横幅（`frame.window`）を、そのまま枠の横幅へ均一に押し込む。
    /// 人: 縮めるだけ（形はそのまま）で、人の中心が「押し込んだ背景の中で人がいた位置」に来るように重ねる。
    ///
    /// 背景にも人は写っているが、押し込まれて細くなった人は同じ中心にいるので、重ねた原寸の人に隠れる。
    /// 人が見つからないときは、押し込まずに縮めるだけの絵になる。
    static func cutout(_ image: CGImage, frame: RotashLens.FrontFrame, canvas: CGSize, live: Bool) -> CGImage? {
        let imageWidth = CGFloat(image.width), imageHeight = CGFloat(image.height)
        let canvasRect = CGRect(origin: .zero, size: canvas)
        // Core Image は左下が原点。写真が占める帯（上下の黒を除いた所）。
        let band = CGRect(x: 0, y: canvas.height - frame.photoTop - frame.photoHeight,
                          width: canvas.width, height: frame.photoHeight)
        let sourceBottom = (1 - frame.sourceY - frame.sourceHeight) * imageHeight
        let scaleY = frame.photoHeight / (frame.sourceHeight * imageHeight)

        let source = CIImage(cgImage: image)
        let mask = LensAnalyzer.personMask(image, live: live)
        let center = mask.flatMap { LensAnalysis(person: LensAnalyzer.columns(ofMask: $0)).personCenter }

        // 人の層。人の中心 xp が、押し込んだ背景の中の同じ位置 up に来るように置く。
        let personX = center ?? 0.5
        let cellX = min(0.95, max(0.05, (personX - frame.windowMinX) / frame.window))
        let personScale = canvas.width / (frame.natural * imageWidth)
        let personTransform = CGAffineTransform(a: personScale, b: 0, c: 0, d: scaleY,
                                                tx: cellX * canvas.width - personX * imageWidth * personScale,
                                                ty: band.minY - sourceBottom * scaleY)
        let person = source.transformed(by: personTransform).cropped(to: band)

        let black = CIImage(color: .black).cropped(to: canvasRect)
        var output = person.composited(over: black)

        if let mask, center != nil {
            // 背景の層。窓全体を枠の横幅へ均一に押し込む。
            let backgroundScale = canvas.width / (frame.window * imageWidth)
            let backgroundTransform = CGAffineTransform(a: backgroundScale, b: 0, c: 0, d: scaleY,
                                                        tx: -frame.windowMinX * imageWidth * backgroundScale,
                                                        ty: band.minY - sourceBottom * scaleY)
            let background = source.transformed(by: backgroundTransform).cropped(to: band)

            // マスクは写真より小さいので、写真の大きさに広げてから人の層と同じように置く。
            let maskImage = CIImage(cvPixelBuffer: mask)
            let toImage = CGAffineTransform(scaleX: imageWidth / maskImage.extent.width,
                                            y: imageHeight / maskImage.extent.height)
            let placedMask = maskImage.transformed(by: toImage.concatenating(personTransform)).cropped(to: band)

            let blended = person.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: background,
                kCIInputMaskImageKey: placedMask
            ])
            output = blended.cropped(to: band).composited(over: black)
        }

        return context.createCGImage(output.cropped(to: canvasRect), from: canvasRect)
    }

    // MARK: - シームカービング

    /// シームカービング（Avidan & Shamir, 2007）。
    ///
    /// 画像の「目立ち具合」（となりの画素との明るさの差）を求め、上から下まで目立たない所をつないだ
    /// 1本の縦の継ぎ目（シーム）を見つけて抜く。これを繰り返して、枠に入れる横幅を縮めるだけの幅まで詰める。
    /// 空や壁のような平らな所から抜けていくので、人や物の形は残りやすい。人物の切り抜きの所は抜かない。
    ///
    /// 重いので、小さくした画像で計算する（ライブビューは高さ 320px、写真は 900px）。
    static func seamCarved(_ image: CGImage, frame: RotashLens.FrontFrame, canvas: CGSize, live: Bool) -> CGImage? {
        let imageWidth = CGFloat(image.width), imageHeight = CGFloat(image.height)
        let crop = CGRect(x: frame.windowMinX * imageWidth, y: frame.sourceY * imageHeight,
                          width: frame.window * imageWidth, height: frame.sourceHeight * imageHeight).integral
        guard crop.width >= 8, crop.height >= 8, let region = image.cropping(to: crop) else { return nil }

        let height = max(8, min(live ? 320 : 900, Int(crop.height)))
        let width = max(8, Int((crop.width * CGFloat(height) / crop.height).rounded()))
        let target = max(4, min(width, Int((CGFloat(width) * frame.natural / frame.window).rounded())))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        // 小さくした画像の画素（1画素 = RGBA を 1 つの UInt32 に）。
        guard let work = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                   bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo),
              let workData = work.data
        else { return nil }
        work.interpolationQuality = .medium
        work.draw(region, in: CGRect(x: 0, y: 0, width: width, height: height))
        let count = width * height
        var pixels = Array(UnsafeBufferPointer(start: workData.bindMemory(to: UInt32.self, capacity: count),
                                               count: count))

        // 目立ち具合。行 0 が画像の上。
        var energy = [Float](repeating: 0, count: count)
        pixels.withUnsafeBufferPointer { px in
            var luma = [Float](repeating: 0, count: count)
            for index in 0..<count {
                let value = px[index]
                // バイトの並びは R, G, B, A（byteOrder32Big）。リトルエンディアンの UInt32 では R が下位。
                let r = Float(value & 0xFF), g = Float((value >> 8) & 0xFF), b = Float((value >> 16) & 0xFF)
                luma[index] = 0.299 * r + 0.587 * g + 0.114 * b
            }
            for y in 0..<height {
                let row = y * width
                let up = max(0, y - 1) * width, down = min(height - 1, y + 1) * width
                for x in 0..<width {
                    let left = max(0, x - 1), right = min(width - 1, x + 1)
                    energy[row + x] = abs(luma[row + right] - luma[row + left])
                        + abs(luma[down + x] - luma[up + x])
                }
            }
        }

        // 人物の切り抜きの所は、ぜったいに抜かれないよう目立ち具合をとても大きくする。
        if let mask = LensAnalyzer.personMask(image, live: live) {
            protect(&energy, width: width, height: height, mask: mask, frame: frame)
        }

        removeSeams(pixels: &pixels, energy: &energy, width: width, height: height, target: target)

        // 詰めた画像（target × height）を作る。
        guard let carvedContext = CGContext(data: nil, width: target, height: height, bitsPerComponent: 8,
                                            bytesPerRow: target * 4, space: colorSpace, bitmapInfo: bitmapInfo),
              let carvedData = carvedContext.data
        else { return nil }
        let carvedPixels = carvedData.bindMemory(to: UInt32.self, capacity: target * height)
        for y in 0..<height {
            for x in 0..<target { carvedPixels[y * target + x] = pixels[y * width + x] }
        }
        guard let carved = carvedContext.makeImage() else { return nil }

        // 枠いっぱいの画像に、上下の黒をつけて置く（CGContext は左下が原点）。
        guard let output = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height),
                                     bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                     bitmapInfo: bitmapInfo)
        else { return nil }
        output.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        output.fill(CGRect(origin: .zero, size: canvas))
        output.interpolationQuality = .high
        output.draw(carved, in: CGRect(x: 0, y: canvas.height - frame.photoTop - frame.photoHeight,
                                       width: canvas.width, height: frame.photoHeight))
        return output.makeImage()
    }

    /// 人物のマスクが白い所の目立ち具合を、抜かれないほど大きくする。
    private static func protect(_ energy: inout [Float], width: Int, height: Int,
                                mask: CVPixelBuffer, frame: RotashLens.FrontFrame) {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return }
        let maskWidth = CVPixelBufferGetWidth(mask), maskHeight = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        guard maskWidth > 0, maskHeight > 0 else { return }
        let maskPixels = base.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            // 小さくした画像の (x, y) が、写真全体のどこにあたるか（0〜1、上が 0）。
            let imageY = frame.sourceY + frame.sourceHeight * (CGFloat(y) + 0.5) / CGFloat(height)
            let maskY = min(maskHeight - 1, max(0, Int(imageY * CGFloat(maskHeight))))
            for x in 0..<width {
                let imageX = frame.windowMinX + frame.window * (CGFloat(x) + 0.5) / CGFloat(width)
                let maskX = min(maskWidth - 1, max(0, Int(imageX * CGFloat(maskWidth))))
                if maskPixels[maskY * bytesPerRow + maskX] > 127 {
                    energy[y * width + x] += 100_000
                }
            }
        }
    }

    /// いちばん目立たない縦の継ぎ目を、幅が `target` になるまで1本ずつ抜く。
    /// 画素と目立ち具合は、行の幅（width）を変えずに左へ詰めていく（右端の使わなくなった所は捨てる）。
    /// 抜くたびに目立ち具合を計算し直すのは重いので、最初に求めた値を一緒に詰めて使い回す。
    private static func removeSeams(pixels: inout [UInt32], energy: inout [Float],
                                    width: Int, height: Int, target: Int) {
        guard target < width, height > 0 else { return }
        var cost = [Float](repeating: 0, count: width * height)

        pixels.withUnsafeMutableBufferPointer { px in
            energy.withUnsafeMutableBufferPointer { en in
                cost.withUnsafeMutableBufferPointer { co in
                    var current = width
                    while current > target {
                        // 上から下へ、各画素まで継ぎ目をつないだときのいちばん小さい目立ち具合の合計。
                        for x in 0..<current { co[x] = en[x] }
                        for y in 1..<max(1, height) {
                            let row = y * width, previous = row - width
                            for x in 0..<current {
                                var best = co[previous + x]
                                if x > 0, co[previous + x - 1] < best { best = co[previous + x - 1] }
                                if x < current - 1, co[previous + x + 1] < best { best = co[previous + x + 1] }
                                co[row + x] = en[row + x] + best
                            }
                        }

                        // いちばん下の行で最小の所から、上へたどりながら抜く。
                        let lastRow = (height - 1) * width
                        var seamX = 0
                        for x in 1..<max(1, current) where co[lastRow + x] < co[lastRow + seamX] { seamX = x }
                        var y = height - 1
                        while y >= 0 {
                            let row = y * width
                            if seamX < current - 1 {
                                for x in seamX..<(current - 1) {
                                    px[row + x] = px[row + x + 1]
                                    en[row + x] = en[row + x + 1]
                                }
                            }
                            if y > 0 {
                                let previous = row - width
                                var next = seamX
                                if seamX > 0, co[previous + seamX - 1] < co[previous + next] { next = seamX - 1 }
                                if seamX < current - 1, co[previous + seamX + 1] < co[previous + next] { next = seamX + 1 }
                                seamX = next
                            }
                            y -= 1
                        }
                        current -= 1
                    }
                }
            }
        }
    }
}
