import UIKit

/// 作品を1枚の画像として書き出す。加工はしない。写真そのもの。
///
/// # なぜ 9:16 の縦なのか
///
/// スマホは基本的に縦で見られていて、Stories / Shorts / TikTok が主戦場である以上、
/// 横長に近い形式はフィード上で小さく表示されて指が止まらない。それが理由の半分。
///
/// もう半分は、**写真の写る量が根本的に違う**こと。
///
///   アプリの1枠   246 × 784   = 1 : 3.2 の縦長  → 16:9 の写真は横幅が 17.7% しか残らない
///   9:16 の1帯   1032 × 223   = 4.6 : 1 の横長  → 横幅が 100% 残る（切れるのは上下）
///
/// つまりアプリは撮った写真の横幅を8割方捨てている。7分割はファインダーであり、
/// この共有画像はプリントにあたる。同じ7枚でも、見えている量が違ってよい。
///
/// # 何を足して、何を足さないか
///
/// 見出し・週の日付・曜日・担当者名は、すでに THIS WEEK の画面が構図の一部として
/// 持っている。別の署名ブロックを下に付け足すと、完成している構図が壊れるだけなので足さない。
/// 足すのは `ROTASH` の1語だけ。「THIS WEEK」は検索できないので、固有名詞が要る。
///
/// # 完成していなくても書き出せる
///
/// 0/7 は招待状、3/7 は「これ何？」、7/7 は作品。**同じ生成器の別の時刻**でしかない。
/// 完成品は答えであり、未完成品は問いなので、途中のほうがむしろ強い。
enum WorkExporter {

    // 1080 × 1920。Instagram / TikTok の縦全画面。
    private static let size = CGSize(width: 1080, height: 1920)
    private static let margin: CGFloat = 24
    private static let bandGap: CGFloat = 3
    private static let bandsTop: CGFloat = 160
    private static let bandsBottom: CGFloat = 1739

    /// 共有用の1枚を書き出す。
    ///
    /// - Parameters:
    ///   - week: 書き出す週。埋まっている枚数は何枚でもよい。
    ///   - group: 担当者の名前を引くために使う。
    ///   - now: 「今日」の判定。未来の担当者を漏らさないために要る。
    static func storyCardURL(for week: RotashWeek,
                             in group: RotashGroup,
                             now: Date = Date()) -> URL? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.rotashBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            drawHeader(week: week)
            drawBands(week: week, group: group, now: now)
            drawFooter(week: week)
        }

        guard let data = image.jpegData(compressionQuality: 0.94) else { return nil }
        let stamp = RotashDateFormat.fileStamp.string(from: week.startDate)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROTASH-\(stamp).jpg")
        return (try? data.write(to: url, options: .atomic)) == nil ? nil : url
    }

    // MARK: - 各部

    private static func drawHeader(week: RotashWeek) {
        draw("THIS WEEK", at: CGPoint(x: margin, y: 52),
             size: 30, weight: .semibold, color: .rotashText, tracking: 6)
        draw(week.dateRange, at: CGPoint(x: margin, y: 100),
             size: 20, color: .rotashFaint, tracking: 3)

        // 何枚そろっているか。未完成であること自体が「これ何？」を生むので、隠さず出す。
        let count = "\(week.filledCount) / \(week.slots.count)"
        let width = measure(count, size: 20, tracking: 3)
        draw(count, at: CGPoint(x: size.width - margin - width, y: 100),
             size: 20, color: .rotashDim, tracking: 3)
    }

    private static func drawBands(week: RotashWeek, group: RotashGroup, now: Date) {
        let slots = week.slots.sorted { $0.dayIndex < $1.dayIndex }
        guard !slots.isEmpty else { return }

        let bandWidth = size.width - margin * 2
        let total = bandsBottom - bandsTop
        let bandHeight = (total - bandGap * CGFloat(slots.count - 1)) / CGFloat(slots.count)
        let todayIndex = Calendar.dayIndex(for: now, weekStart: week.startDate)

        for (position, slot) in slots.enumerated() {
            let band = CGRect(x: margin,
                              y: bandsTop + (bandHeight + bandGap) * CGFloat(position),
                              width: bandWidth,
                              height: bandHeight)
            drawBand(slot: slot,
                     band: band,
                     week: week,
                     group: group,
                     todayIndex: todayIndex,
                     now: now)
        }
    }

    private static func drawBand(slot: Slot,
                                 band: CGRect,
                                 week: RotashWeek,
                                 group: RotashGroup,
                                 todayIndex: Int,
                                 now: Date) {
        UIColor.rotashSurface.setFill()
        UIRectFill(band)

        // 写真は正立させたまま、横帯に aspectFill する。
        // 画面と違って横幅は切らないので、風景も食事も街もそのまま残る。
        if let filename = slot.photoFilename,
           let photo = PhotoStore.shared.image(for: filename),
           let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            context.clip(to: band)
            photo.draw(in: aspectFillRect(imageSize: photo.size, in: band))
            context.restoreGState()
        } else if week.state(of: slot, now: now) == .noShot {
            // 撮られないまま終わった日。失敗ではなく作品上の状態なので、静かに置く。
            let dash = "—"
            let width = measure(dash, size: 26, tracking: 0)
            draw(dash,
                 at: CGPoint(x: band.midX - width / 2, y: band.midY - 18),
                 size: 26, color: .rotashFaint, tracking: 0)
        }

        drawLabelScrim(in: band)

        let labelY = band.maxY - 40
        draw(RotashDay.label(for: slot.dayIndex),
             at: CGPoint(x: band.minX + 18, y: labelY),
             size: 22, color: .rotashText, tracking: 3)

        // 未来の担当者は誰にも見せていない。共有画像でも同じ扱いにする。
        // ここを漏らすと、Rotash 最大の資産（次に誰が撮るか分からないこと）が
        // アプリの外から壊れる。
        if slot.dayIndex <= todayIndex,
           let name = group.member(forDay: slot.dayIndex, in: week)?.name {
            draw(name.uppercased(),
                 at: CGPoint(x: band.minX + 108, y: labelY + 4),
                 size: 17, color: .rotashDim, tracking: 1.4)
        }

        // 今日の帯。進行中の共有では「これは今まさに起きている」という情報になる。
        if slot.dayIndex == todayIndex, !week.isFinished {
            UIColor.rotashLive.setFill()
            UIRectFill(CGRect(x: band.minX, y: band.minY, width: band.width, height: 3))
        }
    }

    /// ラベルが明るい写真に埋もれないように、帯の下だけ薄く落とす。
    private static func drawLabelScrim(in band: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let height: CGFloat = 62
        let rect = CGRect(x: band.minX, y: band.maxY - height, width: band.width, height: height)
        let colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.72).cgColor]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0, 1]) else { return }
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: rect.minX, y: rect.minY),
                                   end: CGPoint(x: rect.minX, y: rect.maxY),
                                   options: [])
        context.restoreGState()
    }

    private static func drawFooter(week: RotashWeek) {
        // タイトルは、この画像に載る唯一の人間の声。
        // 曜日も日付も担当者名もシステムが生成したものなので、
        // これが無いとどれだけ作り込んでも自動生成された広告に見える。
        if let title = week.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            draw(title, at: CGPoint(x: margin, y: 1768),
                 size: 30, weight: .regular, color: .rotashText, tracking: 1, monospaced: false)
        }

        // 画面に唯一足りないもの。「THIS WEEK」は検索できない。
        draw("ROTASH", at: CGPoint(x: margin, y: 1834),
             size: 26, weight: .bold, color: .rotashText, tracking: 9)
    }

    // MARK: - 描画の道具

    private static func attributes(size: CGFloat,
                                   weight: UIFont.Weight,
                                   color: UIColor,
                                   tracking: CGFloat,
                                   monospaced: Bool) -> [NSAttributedString.Key: Any] {
        let font = monospaced
            ? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
        return [.font: font, .foregroundColor: color, .kern: tracking]
    }

    private static func draw(_ text: String,
                             at point: CGPoint,
                             size: CGFloat,
                             weight: UIFont.Weight = .medium,
                             color: UIColor,
                             tracking: CGFloat,
                             monospaced: Bool = true) {
        NSAttributedString(string: text,
                           attributes: attributes(size: size,
                                                  weight: weight,
                                                  color: color,
                                                  tracking: tracking,
                                                  monospaced: monospaced))
            .draw(at: point)
    }

    private static func measure(_ text: String,
                                size: CGFloat,
                                weight: UIFont.Weight = .medium,
                                tracking: CGFloat,
                                monospaced: Bool = true) -> CGFloat {
        NSAttributedString(string: text,
                           attributes: attributes(size: size,
                                                  weight: weight,
                                                  color: .rotashText,
                                                  tracking: tracking,
                                                  monospaced: monospaced))
            .size().width
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
