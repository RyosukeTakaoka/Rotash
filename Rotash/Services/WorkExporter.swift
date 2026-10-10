import UIKit

/// 共有画像の形。まだ確定していないので、フラグ1つで入れ替えられるようにしておく。
enum ShareCardFormat {
    /// 撮影画面そのもの。横長 1920 × 1080 に組んだものを、
    /// **中身は一切変えずに時計まわりへ90度倒して** 1080 × 1920 で書き出す。
    ///
    /// 画面で見ているものと配られる画像が、字の向きまで含めて同じ絵になる。
    /// 「これ何？」と聞かれて端末を横にすれば、そのままの並びが出てくる。
    /// 受け取る側は縦のフィードで大きく見られるので、9:16 の器も無駄にならない。
    ///
    /// 右まわりにするのは、横長の左端＝月曜が上に来るから。
    /// 7枚が上から下へ曜日の順に並び、縦のフィードでそのまま読み下せる。
    case screen

    /// Stories / TikTok 向けの縦。1080 × 1920。7枚を横帯に積み直す。
    ///
    /// 1枠あたりの写真は横幅が丸ごと残る（画面の縦長の枠は、元の写真の
    /// 横幅を8割方捨てている）。ただし7分割の並びは画面と別物になるので、
    /// 見せられた側は同じ絵を想像できない。
    case story
}

/// 作品を1枚の画像として書き出す。加工はしない。写真そのもの。
///
/// # いまは「撮影画面をそのまま倒したもの」
///
/// 組むのは横長 1920 × 1080 の7分割 —— 撮影画面と同じ並び。
/// それを**中身に一切手を入れず、時計まわりに90度倒して** 1080 × 1920 で書き出す。
///
/// 7枚を積み直して縦組みにすると1枠あたりの写真は多く見えるが、並びが画面と別物になり、
/// 受け取った人が画像とアプリを結びつけられない。倒すだけなら並びは画面のままで、
/// しかも縦のフィードで大きく表示される。器と中身を別々に決められる。
///
/// 積み直した縦のほうがよいと分かったら
/// `RotashFeatureFlags.shareCardFormat` を `.story` に変える。
/// 倒さず横長のまま出したくなったら、`Layout.rotates` を false にする。
///
/// # 何を足して、何を足さないか
///
/// 見出し・週の日付・曜日・担当者名は、すでに THIS WEEK の画面が構図の一部として
/// 持っている。別の署名ブロックを付け足すと、完成している構図が壊れるだけなので足さない。
/// 足すのは `ROTASH` の1語だけ。「THIS WEEK」は検索できないので、固有名詞が要る。
///
/// # 完成していなくても書き出せる
///
/// 0/7 は招待状、3/7 は「これ何？」、7/7 は作品。**同じ生成器の別の時刻**でしかない。
/// 完成品は答えであり、未完成品は問いなので、途中のほうがむしろ強い。
enum WorkExporter {

    // MARK: - 書き出し

    /// 共有用の1枚を書き出して、その場所を返す。
    ///
    /// 画像そのものではなくファイルにするのは、共有先で
    /// `ROTASH-20260906.jpg` という名前のまま届くようにするため。
    ///
    /// - Parameters:
    ///   - week: 書き出す週。埋まっている枚数は何枚でもよい。
    ///   - group: 担当者の名前を引くために使う。
    ///   - now: 「今日」の判定。未来の担当者を漏らさないために要る。
    static func shareCardURL(for week: RotashWeek,
                             in group: RotashGroup,
                             now: Date = Date()) -> URL? {
        guard let image = shareCard(for: week, in: group, now: now),
              let data = image.jpegData(compressionQuality: 0.94)
        else { return nil }

        // 週の途中から始めた週は、作品の初日（月曜ではない）の日付にする。
        let stamp = RotashDateFormat.fileStamp.string(from: week.displayStartDate)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ROTASH-\(stamp).jpg")
        return (try? data.write(to: url, options: .atomic)) == nil ? nil : url
    }

    static func shareCard(for week: RotashWeek,
                          in group: RotashGroup,
                          now: Date = Date()) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let layout = Layout(format: RotashFeatureFlags.shareCardFormat)

        return UIGraphicsImageRenderer(size: layout.output, format: format).image { context in
            // 倒すのは座標系だけ。以降の描画は、横長のときと1ピクセルも変わらない。
            // 出来上がった画像を回すのではなく最初から回した座標系に描くので、
            // 文字も写真も倒したあとの解像度で描かれる（描き直しによる劣化が無い）。
            //
            // 右まわり（時計まわり）に倒す。横長の左端＝月曜が上に来るので、
            // 縦に並んだ7枚を上から下へ、曜日の順に読み下せる。
            if layout.rotates {
                context.cgContext.translateBy(x: layout.output.width, y: 0)
                context.cgContext.rotate(by: .pi / 2)
            }

            UIColor.rotashBackground.setFill()
            UIRectFill(CGRect(origin: .zero, size: layout.canvas))
            drawHeader(week: week, layout: layout)
            drawFrames(week: week, group: group, now: now, layout: layout)
            drawFooter(week: week, group: group, layout: layout)
        }
    }

    // MARK: - 寸法

    /// 形ごとの寸法をまとめたもの。
    /// 描画の手続きは横でも縦でも同じで、違うのは「枠をどう並べるか」だけにする。
    private struct Layout {
        let format: ShareCardFormat
        /// 組み立てるときの座標系の大きさ。描画のコードはすべてこの中で考える。
        let canvas: CGSize
        /// 描いたものを時計まわりに90度倒すか。
        /// false にすれば、組んだままの横長で書き出される。
        let rotates: Bool
        /// 書き出される画像の大きさ。倒す場合は縦横が入れ替わる。
        var output: CGSize {
            rotates ? CGSize(width: canvas.height, height: canvas.width) : canvas
        }
        /// 枠の並ぶ領域。
        let frames: CGRect
        /// 文字まわりの余白。
        let margin: CGFloat
        /// 枠と枠のすきま。
        let gap: CGFloat
        /// 見出しの文字の大きさ。
        let headline: CGFloat
        let caption: CGFloat
        /// 枠の中に置くラベル。
        let dayLabel: CGFloat
        let nameLabel: CGFloat
        let labelInset: CGFloat
        /// 今日を示す線の太さ。
        let liveBar: CGFloat

        init(format: ShareCardFormat) {
            self.format = format
            switch format {
            case .screen:
                // 画面と同じく、7分割は左右いっぱいまで使う（端の余白を作らない）。
                // 組むのは横長。書き出しはこれを倒した 1080 × 1920 になる。
                canvas = CGSize(width: 1920, height: 1080)
                rotates = true
                frames = CGRect(x: 0, y: 96, width: 1920, height: 876)
                margin = 36
                gap = 3
                headline = 30
                caption = 20
                dayLabel = 26
                nameLabel = 19
                labelInset = 26
                liveBar = 5
            case .story:
                canvas = CGSize(width: 1080, height: 1920)
                rotates = false
                frames = CGRect(x: 24, y: 160, width: 1032, height: 1579)
                margin = 24
                gap = 3
                headline = 30
                caption = 20
                dayLabel = 22
                nameLabel = 17
                labelInset = 18
                liveBar = 3
            }
        }

        /// 枠を並べる向き。横長は縦に切って左から、縦長は横に切って上から。
        func rect(at position: Int, of count: Int) -> CGRect {
            let total = max(count, 1)
            switch format {
            case .screen:
                let width = (frames.width - gap * CGFloat(total - 1)) / CGFloat(total)
                return CGRect(x: frames.minX + (width + gap) * CGFloat(position),
                              y: frames.minY, width: width, height: frames.height)
            case .story:
                let height = (frames.height - gap * CGFloat(total - 1)) / CGFloat(total)
                return CGRect(x: frames.minX,
                              y: frames.minY + (height + gap) * CGFloat(position),
                              width: frames.width, height: height)
            }
        }
    }

    // MARK: - 各部

    private static func drawHeader(week: RotashWeek, layout: Layout) {
        switch layout.format {
        case .screen:
            // 画面のヘッダーと同じ並び。THIS WEEK / 日付 / 何枚そろっているか。
            var x = layout.margin
            draw("THIS WEEK", at: CGPoint(x: x, y: 30),
                 size: layout.headline, weight: .semibold, color: .rotashText, tracking: 6)
            x += measure("THIS WEEK", size: layout.headline, weight: .semibold, tracking: 6) + 22

            draw(week.dateRange, at: CGPoint(x: x, y: 40),
                 size: layout.caption, color: .rotashFaint, tracking: 3)
            x += measure(week.dateRange, size: layout.caption, tracking: 3) + 20

            draw(counter(week), at: CGPoint(x: x, y: 40),
                 size: layout.caption, color: .rotashDim, tracking: 3)

            // 画面ではヘッダーと7分割のあいだに細い線が1本ある。
            UIColor.rotashLine.setFill()
            UIRectFill(CGRect(x: 0, y: layout.frames.minY - 1, width: layout.canvas.width, height: 1))

        case .story:
            draw("THIS WEEK", at: CGPoint(x: layout.margin, y: 52),
                 size: layout.headline, weight: .semibold, color: .rotashText, tracking: 6)
            draw(week.dateRange, at: CGPoint(x: layout.margin, y: 100),
                 size: layout.caption, color: .rotashFaint, tracking: 3)
            drawRightAligned(counter(week), rightEdge: layout.canvas.width - layout.margin, y: 100,
                             size: layout.caption, color: .rotashDim, tracking: 3)
        }
    }

    /// 何枚そろっているか。未完成であること自体が「これ何？」を生むので、隠さず出す。
    private static func counter(_ week: RotashWeek) -> String {
        "\(week.filledCount) / \(week.slots.count)"
    }

    private static func drawFrames(week: RotashWeek,
                                   group: RotashGroup,
                                   now: Date,
                                   layout: Layout) {
        let slots = week.slots.sorted { $0.dayIndex < $1.dayIndex }
        guard !slots.isEmpty else { return }
        let todayIndex = Calendar.dayIndex(for: now, weekStart: week.startDate)

        for (position, slot) in slots.enumerated() {
            drawFrame(slot: slot,
                      rect: layout.rect(at: position, of: slots.count),
                      week: week,
                      group: group,
                      todayIndex: todayIndex,
                      now: now,
                      layout: layout)
        }
    }

    private static func drawFrame(slot: Slot,
                                  rect: CGRect,
                                  week: RotashWeek,
                                  group: RotashGroup,
                                  todayIndex: Int,
                                  now: Date,
                                  layout: Layout) {
        UIColor.rotashSurface.setFill()
        UIRectFill(rect)

        // 写真は枠いっぱいに収める（画面の PhotoImageView と同じ scaledToFill）。
        // 横長の枠は画面とほぼ同じ比率なので、切れ方も画面で見たときと同じになる。
        // 写真は表（撮るとき大きい画面に映っていた方）。裏は下に丸で添える（drawReverseBadge）。
        if let image = photo(for: slot),
           let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            context.clip(to: rect)
            image.draw(in: aspectFillRect(imageSize: image.size, in: rect))
            context.restoreGState()
        } else if week.state(of: slot, now: now) == .noShot {
            // 撮られないまま終わった日。失敗ではなく作品上の状態なので、静かに置く。
            drawCentered("—", in: rect, size: layout.dayLabel + 4,
                         color: .rotashFaint, tracking: 0)
        }

        drawLabelScrim(in: rect, layout: layout)
        drawReverseBadge(slot: slot, in: rect, layout: layout)

        // 未来の担当者は誰にも見せていない。共有画像でも同じ扱いにする。
        // ここを漏らすと、Rotash 最大の資産（次に誰が撮るか分からないこと）が
        // アプリの外から壊れる。
        let name = slot.dayIndex <= todayIndex
            ? group.member(forDay: slot.dayIndex, in: week)?.name.uppercased()
            : nil

        drawFrameLabels(day: RotashDay.label(for: slot.dayIndex),
                        name: name,
                        isFilled: slot.isFilled,
                        in: rect,
                        layout: layout)

        // 今日の枠。進行中の共有では「これは今まさに起きている」という情報になる。
        if slot.dayIndex == todayIndex, !week.isFinished {
            UIColor.rotashLive.setFill()
            UIRectFill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: layout.liveBar))
        }
    }

    /// 曜日と担当者名。横長は画面と同じく枠の上に中央そろえ、縦長は帯なので左そろえ。
    private static func drawFrameLabels(day: String,
                                        name: String?,
                                        isFilled: Bool,
                                        in rect: CGRect,
                                        layout: Layout) {
        let dayColor: UIColor = isFilled ? .rotashText : .rotashDim

        switch layout.format {
        case .screen:
            // 曜日は枠の上、裏の丸は枠の下。真ん中（写真の主役が来るところ）は空けておく。
            let dayTop = rect.minY + layout.labelInset
            drawCentered(day, in: rect, atTop: dayTop,
                         size: layout.dayLabel, color: dayColor, tracking: 3.4)
            if let name {
                drawCentered(name, in: rect, atTop: dayTop + layout.dayLabel * 1.25 + 7,
                             size: layout.nameLabel, color: .rotashFaint, tracking: 1.8)
            }

        case .story:
            let top = rect.maxY - 40
            draw(day, at: CGPoint(x: rect.minX + layout.labelInset, y: top),
                 size: layout.dayLabel, color: dayColor, tracking: 3)
            if let name {
                draw(name, at: CGPoint(x: rect.minX + layout.labelInset + 90, y: top + 4),
                     size: layout.nameLabel, color: .rotashDim, tracking: 1.4)
            }
        }
    }

    /// ラベルが明るい写真に埋もれないように、ラベルのある側だけ薄く落とす。
    /// 横長は枠の上（画面と同じく上から 0.3 まで）、縦長は帯の下（0.62 から下）。
    private static func drawLabelScrim(in rect: CGRect, layout: Layout) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let band: CGRect
        let start: CGPoint
        let end: CGPoint
        switch layout.format {
        case .screen:
            band = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.3)
            start = CGPoint(x: band.minX, y: band.maxY)
            end = CGPoint(x: band.minX, y: band.minY)
        case .story:
            band = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.62,
                          width: rect.width, height: rect.height * 0.38)
            start = CGPoint(x: band.minX, y: band.minY)
            end = CGPoint(x: band.minX, y: band.maxY)
        }
        let colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.62).cgColor]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0, 1]) else { return }
        context.saveGState()
        context.clip(to: band)
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
        context.restoreGState()
    }

    /// 裏の写真を丸にして添える。撮るときのシャッターの丸と同じ形（白いふち）。
    /// 横長は枠の下の真ん中、縦長は帯の右端。裏の写真が無い日は何も描かない。
    private static func drawReverseBadge(slot: Slot, in rect: CGRect, layout: Layout) {
        guard RotashFeatureFlags.shareShowsReverseBadge,
              slot.isFilled,
              let image = reversePhoto(for: slot),
              let context = UIGraphicsGetCurrentContext()
        else { return }

        let circle: CGRect
        switch layout.format {
        case .screen:
            // 画面と同じ決まり（細い枠は下の真ん中、週の途中から始めた広い枠は右下）。
            let placement = ReverseBadge.placement(in: rect.size)
            let diameter = placement.diameter
            circle = CGRect(x: placement.centered
                                ? rect.midX - diameter / 2
                                : rect.maxX - layout.labelInset - diameter,
                            y: rect.maxY - layout.labelInset - diameter,
                            width: diameter, height: diameter)
        case .story:
            // 帯が横に長い（週の途中から始めた最初の週）と高さだけで決めると写真を覆うので、幅でも上限を決める。
            let diameter = min(rect.height * ReverseBadge.widthRatio, rect.width * 0.3)
            circle = CGRect(x: rect.maxX - layout.labelInset - diameter,
                            y: rect.midY - diameter / 2,
                            width: diameter, height: diameter)
        }

        // 撮るときの丸と同じく、写真に入るいちばん大きな丸を縮めて入れる（丸いっぱいに広げる）。
        context.saveGState()
        context.addEllipse(in: circle)
        context.clip()
        image.draw(in: aspectFillRect(imageSize: image.size, in: circle))
        context.restoreGState()

        let ring: CGFloat = 4
        UIColor.white.setStroke()
        let path = UIBezierPath(ovalIn: circle.insetBy(dx: -ring / 2, dy: -ring / 2))
        path.lineWidth = ring
        path.stroke()
    }

    private static func drawFooter(week: RotashWeek, group: RotashGroup, layout: Layout) {
        let title = week.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // ROTASH の寸法。名前はこれを基準に並べる。
        // 字間は最後の1文字のうしろにも入るので、見た目の幅はその分を引いたもの。
        let wordmarkSize: CGFloat = 26
        let wordmarkTracking: CGFloat = 9
        let wordmarkWidth = measure("ROTASH", size: wordmarkSize, weight: .bold,
                                    tracking: wordmarkTracking) - wordmarkTracking

        // 撮った人の名前。日付や枚数と同じ控えめな文字で、ROTASH の隣に添える。
        // ROTASH と1語に読まれないよう、あいだに縦棒を挟む。
        let names = photographerNames(in: week, group: group)
        let nameSize = layout.caption
        let nameTracking: CGFloat = 3
        // 大きさの違う ROTASH と同じベースラインに置くための、上端のずれ。
        let nameDrop = ascender(size: wordmarkSize, weight: .bold) - ascender(size: nameSize)
        let bar = "|"
        let barWidth = measure(bar, size: nameSize, tracking: 0)
        let barGap: CGFloat = 20

        switch layout.format {
        case .screen:
            let baseline = layout.frames.maxY + 32
            // タイトルは、この画像に載る唯一の人間の声。
            // 曜日も日付も担当者名もシステムが生成したものなので、
            // これが無いとどれだけ作り込んでも自動生成された広告に見える。
            if !title.isEmpty {
                draw(title, at: CGPoint(x: layout.margin, y: baseline),
                     size: layout.headline, weight: .regular, color: .rotashText,
                     tracking: 1, monospaced: false)
            }
            // 画面に唯一足りないもの。「THIS WEEK」は検索できない。
            let wordmarkY = baseline + 4
            let rightEdge = layout.canvas.width - layout.margin
            drawRightAligned("ROTASH", rightEdge: rightEdge, y: wordmarkY,
                             size: wordmarkSize, weight: .bold, color: .rotashText,
                             tracking: wordmarkTracking)

            // 名前は ROTASH の左へ、右そろえで伸ばす。
            // 左にはタイトルがあるので、そこへ食い込む前に名前を打ち切る（タイトルのほうが大事）。
            let barRight = rightEdge - wordmarkWidth - barGap
            let namesRight = barRight - barWidth - barGap
            let titleRight = title.isEmpty
                ? layout.margin
                : layout.margin + measure(title, size: layout.headline, weight: .regular,
                                          tracking: 1, monospaced: false) - 1
            let credits = fittedNames(names, maxWidth: namesRight - (titleRight + 48),
                                      size: nameSize, tracking: nameTracking)
            if !credits.isEmpty {
                drawRightAligned(bar, rightEdge: barRight, y: wordmarkY + nameDrop,
                                 size: nameSize, color: .rotashFaint, tracking: 0)
                drawRightAligned(credits, rightEdge: namesRight, y: wordmarkY + nameDrop,
                                 size: nameSize, color: .rotashDim, tracking: nameTracking)
            }

        case .story:
            if !title.isEmpty {
                draw(title, at: CGPoint(x: layout.margin, y: 1768),
                     size: layout.headline, weight: .regular, color: .rotashText,
                     tracking: 1, monospaced: false)
            }
            let wordmarkY: CGFloat = 1834
            draw("ROTASH", at: CGPoint(x: layout.margin, y: wordmarkY),
                 size: wordmarkSize, weight: .bold, color: .rotashText, tracking: wordmarkTracking)

            // 縦長は ROTASH が左端にあるので、名前はその右へ左そろえで伸ばし、右の余白で打ち切る。
            let barX = layout.margin + wordmarkWidth + barGap
            let namesX = barX + barWidth + barGap
            let credits = fittedNames(names, maxWidth: layout.canvas.width - layout.margin - namesX,
                                      size: nameSize, tracking: nameTracking)
            if !credits.isEmpty {
                draw(bar, at: CGPoint(x: barX, y: wordmarkY + nameDrop),
                     size: nameSize, color: .rotashFaint, tracking: 0)
                draw(credits, at: CGPoint(x: namesX, y: wordmarkY + nameDrop),
                     size: nameSize, color: .rotashDim, tracking: nameTracking)
            }
        }
    }

    /// その週に1枚でも撮った人の名前（大文字）。最初に撮った曜日の順に、重複なく並べる。
    ///
    /// 担当者（assigneeID）ではなく、実際に撮った人（takenByMemberID）だけを数える。
    /// まだ撮っていない日の担当者はここに出てこないので、未来の担当者が漏れることもない。
    /// グループを抜けて引けなくなった人は、名前が分からないので載せない。
    private static func photographerNames(in week: RotashWeek, group: RotashGroup) -> [String] {
        var seen = Set<UUID>()
        var names: [String] = []
        for slot in week.slots.sorted(by: { $0.dayIndex < $1.dayIndex }) where slot.isFilled {
            guard let id = slot.takenByMemberID, !seen.contains(id) else { continue }
            seen.insert(id)
            guard let member = group.member(withID: id) else { continue }
            let name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { names.append(name.uppercased()) }
        }
        return names
    }

    /// 名前を `maxWidth` に収まる分だけ、2つの空白で区切って並べる。
    /// 収まらなければ後ろから落として、落とした人数を `+N` で添える（誰かが消えたことは隠さない）。
    /// `+N` すら入らないとき、または名前が1つも無いときは空文字を返す。
    private static func fittedNames(_ names: [String],
                                    maxWidth: CGFloat,
                                    size: CGFloat,
                                    tracking: CGFloat) -> String {
        guard !names.isEmpty, maxWidth > 0 else { return "" }
        for count in stride(from: names.count, through: 0, by: -1) {
            let dropped = names.count - count
            var parts = Array(names.prefix(count))
            if dropped > 0 { parts.append("+\(dropped)") }
            let text = parts.joined(separator: "  ")
            if measure(text, size: size, tracking: tracking) - tracking <= maxWidth {
                return text
            }
        }
        return ""
    }

    // MARK: - 写真

    /// その枠の写真。手元に無ければ描かない（同期でキャッシュされるまで空のまま）。
    private static func photo(for slot: Slot) -> UIImage? {
        guard let filename = slot.photoFilename else { return nil }
        return PhotoStore.shared.image(for: filename)
    }

    /// その枠の裏の写真。丸に入れるだけなので、小さく読む。
    private static func reversePhoto(for slot: Slot) -> UIImage? {
        guard let filename = slot.reversePhotoFilename else { return nil }
        return PhotoStore.shared.image(for: filename, maxPixel: 600)
    }

    // MARK: - 描画の道具

    private static func attributes(size: CGFloat,
                                   weight: UIFont.Weight,
                                   color: UIColor,
                                   tracking: CGFloat,
                                   monospaced: Bool) -> [NSAttributedString.Key: Any] {
        [.font: font(size: size, weight: weight, monospaced: monospaced),
         .foregroundColor: color,
         .kern: tracking]
    }

    /// 文字の書体。描くときと寸法を測るときで同じものを使うために、ここだけで決める。
    private static func font(size: CGFloat, weight: UIFont.Weight, monospaced: Bool) -> UIFont {
        monospaced
            ? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
    }

    /// 行の上端からベースラインまでの高さ。
    /// `draw(at:)` は行の上端を基準に置くので、大きさの違う文字を同じベースラインに並べるには
    /// この差だけ下げればよい。
    private static func ascender(size: CGFloat,
                                 weight: UIFont.Weight = .medium,
                                 monospaced: Bool = true) -> CGFloat {
        font(size: size, weight: weight, monospaced: monospaced).ascender
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

    /// 右そろえ。字間は最後の1文字のうしろにも入るので、その分だけ戻して端を揃える。
    private static func drawRightAligned(_ text: String,
                                         rightEdge: CGFloat,
                                         y: CGFloat,
                                         size: CGFloat,
                                         weight: UIFont.Weight = .medium,
                                         color: UIColor,
                                         tracking: CGFloat) {
        let width = measure(text, size: size, weight: weight, tracking: tracking) - tracking
        draw(text, at: CGPoint(x: rightEdge - width, y: y),
             size: size, weight: weight, color: color, tracking: tracking)
    }

    private static func drawCentered(_ text: String,
                                     in rect: CGRect,
                                     atTop top: CGFloat? = nil,
                                     size: CGFloat,
                                     color: UIColor,
                                     tracking: CGFloat) {
        let width = measure(text, size: size, tracking: tracking) - tracking
        draw(text,
             at: CGPoint(x: rect.midX - width / 2, y: top ?? (rect.midY - size * 0.7)),
             size: size, color: color, tracking: tracking)
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
