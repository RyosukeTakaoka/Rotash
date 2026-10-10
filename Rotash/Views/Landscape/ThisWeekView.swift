import Combine
import SwiftUI
import UIKit

/// 横向きのメイン体験。
/// 7分割は誰にでも常に全部見える。撮影だけがその日の担当者に限られる。
struct ThisWeekView: View {

    @EnvironmentObject private var app: AppViewModel
    @StateObject private var camera = CameraController()

    @State private var manualSelection: Int?
    @State private var isCapturing = false
    /// 長押しで裏返している枠（曜日）。裏はいつでも見られる。
    @State private var flippedDays: Set<Int> = []
    @State private var flashOpacity: Double = 0
    /// 撮るときの大きい画面の幅が、今日の枠の幅の何倍か。1 は元の7分割の枠のまま（はじめはこれ）。
    /// ピンチで広げたり縮めたりできる。いちばん広いのは7分割（月〜日）の横幅いっぱい。
    /// 見る範囲を変えるだけで、保存する写真はいつもカメラの映像そのまま（4:3）。
    @State private var liveScale: CGFloat = 1
    /// ピンチを始めたときの liveScale。ピンチの倍率はこれに掛ける。
    @State private var pinchBaseScale: CGFloat?
    /// 全画面で大きく見ている日（写真のある枠を押すと開く）。
    @State private var viewerDay: Int?
    /// 全画面で、丸を押して大きい写真と丸を入れ替えているか。
    @State private var viewerSwapped = false
    @State private var draftTitle = ""
    /// 撮り直せる残り時間を数えるための「いま」。撮り直せるあいだだけ進める。
    /// 表示を描き直すきっかけとして使う。撮れるかどうかの判定そのものは常に本物の現在時刻で行う。
    @State private var now = Date()
    /// 撮り直しの残り秒数を数える時計。`body` の中で作ると描き直すたびに作り直されて刻まなくなるので、
    /// プロパティとして持つ（ThisWeekView 自体が作り直されたときだけ新しくなる）。
    private let clock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private var week: RotashWeek? { app.group?.currentWeek }

    /// いま撮影対象になっている枠（= ライブビューが出ている枠）。
    /// タップで選ぶと、撮影済みの枠でも撮り直しとして選択できる。
    ///
    /// 週の最後の1枚を撮ると週は「完成」になるが、撮った直後の撮り直しだけは
    /// 他の日と同じようにできるようにする（最後の1枚だけ事故を救えないのは不公平なので）。
    private var activeDay: Int? {
        guard let week else { return nil }
        if let manualSelection, app.canShoot(dayIndex: manualSelection) { return manualSelection }
        guard !week.isFinished else { return nil }
        return app.autoActiveDay
    }

    private var isRetake: Bool {
        guard let activeDay, let week else { return false }
        return week.slot(at: activeDay)?.isFilled ?? false
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if let week {
                VStack(spacing: 0) {
                    header(week: week)
                    HairLine()
                    // 進行中も完成後も、7分割は同じ大きさ・同じ位置のまま。
                    // 完成したことは、見出しの COMPLETE と、その週の名前（見出しに出る）で伝える。
                    grid(week: week)
                }
                .overlay(alignment: .bottom) { bottomControl(week: week) }
            }

            if let viewerDay, let slot = week?.slot(at: viewerDay), slot.isFilled {
                photoViewer(slot)
                    .transition(.opacity)
                    .zIndex(1)
            }

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear { syncCamera() }
        .onDisappear { camera.stop() }
        .onChange(of: activeDay) { oldDay, newDay in
            // 撮り始めるたびに、ライブビューは元の7分割の枠の大きさから始める。
            if oldDay == nil, newDay != nil { liveScale = 1 }
            syncCamera()
        }
        // 週が変わったら、前の週で裏返していた曜日を引き継がない（新しい週の同じ曜日が裏返って見えないように）。
        .onChange(of: week?.id) { _, _ in
            flippedDays = []
            liveScale = 1
            // グループを切り替えたときも、前のグループの選択や全画面を持ち越さない。
            manualSelection = nil
            viewerDay = nil
        }
        // 撮り直せる時間のあいだだけ時計を進め、残り秒数と「時間切れでカメラを閉じる」を画面に反映する。
        .onReceive(clock) { date in
            // 「いま撮り直せるか」ではなく「締め切りがまだ来ていないか」で進める。
            // 前者で判定すると、撮り直しの途中で日付が変わって撮れなくなった瞬間に時計が止まり、
            // 描き直しも起きないので RETAKE ボタンや残り秒数が画面に残ったままになる。
            if let deadline = app.latestRetakeDeadline, now <= deadline { now = date }
        }
        // 横にした時点で最新を取りに行く。作品を見る画面なので、
        // ここに来たら必ず最新が見えている状態にしたい。
        .task { await app.sync() }
    }

    // MARK: - Header

    private func header(week: RotashWeek) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            // 掛け持ちしているときは、どのグループの週かを先頭に出す。
            if app.groups.count > 1, let name = app.group?.name {
                Text(name.uppercased())
                    .rotashLabel(10, color: Palette.dim, tracking: 1.6)
                    .lineLimit(1)
                Text("|").rotashLabel(10, color: Palette.faint, tracking: 0)
            }
            Text("THIS WEEK")
                .rotashLabel(12, color: Palette.text, tracking: 3.4)
            Text(week.dateRange)
                .rotashLabel(10, color: Palette.faint)
            if week.isFinished {
                // 完成した週。画面の並びは変えず、ここだけで伝える。
                Text("COMPLETE")
                    .rotashLabel(10, color: Palette.live, tracking: 1.8)
            } else {
                Text("\(week.filledCount) / \(week.slots.count)")
                    .rotashLabel(10, color: Palette.dim, tracking: 1.4)
            }
            titleArea(week: week)
            Spacer(minLength: 8)
            // 完成を待たずに共有できる。3/7 は「これ何？」を生むが、7/7 は答えなので、
            // 途中のほうがむしろ強い。押し付けはしない — ここに静かに置いておくだけ。
            WorkShareButton(week: week) {
                Text("SHARE")
                    .rotashLabel(11,
                                 color: week.isFinished ? Palette.live : Palette.dim,
                                 tracking: 2.4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - 決着した週
    //
    // 以前は、完成した週を一回り小さくして余白に置き、上に過去の週の帯を重ねていた。
    // 「終わった」を見え方の変化で伝え、積み重ねの上に載せるためだったが、
    // 撮った瞬間に7分割が動き、上の帯も切れた写真に見えて、不具合のように感じられた。
    // いまは7分割をそのまま残し、見出しの COMPLETE と週の名前だけで伝える。
    // 積み重ね（過去の週）は Memories で見せる。

    /// その週の一行（見出しの中に出す）。
    ///
    /// 書けるのは **7枚目を撮った本人だけ**。全員が書けるようにすると、
    /// それはタイトルではなくコメント欄になる。
    /// 空のままでも作品は成立するので、催促はしない。
    @ViewBuilder
    private func titleArea(week: RotashWeek) -> some View {
        if let title = week.title, !title.isEmpty {
            Text(title)
                .font(Typo.title(13))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
        } else if week.isFinished, app.titlableWeek?.id == week.id, app.retakeWindow(now: now) == nil {
            // 撮り直せるあいだは写真がまだ確定していないので、名前をつける欄は出さない。
            HStack(spacing: 10) {
                TextField("", text: $draftTitle,
                          prompt: Text("この1週間に名前をつける"))
                    .textFieldStyle(.plain)
                    .font(Typo.title(13))
                    .foregroundStyle(Palette.text)
                    .submitLabel(.done)
                    .onSubmit { commitTitle(for: week) }
                    .frame(maxWidth: 260)

                Button("つける") { commitTitle(for: week) }
                    .font(Typo.label(10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(draftTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? Palette.faint : Palette.live)
                    .buttonStyle(.plain)
            }
        }
    }

    /// 長さを詰めるのは確定したこの時点だけにする。
    /// 入力中に書き換えると日本語変換が壊れる（README「日本語入力について」）。
    private func commitTitle(for week: RotashWeek) {
        app.setTitle(draftTitle, for: week)
        draftTitle = ""
    }

    // MARK: - 7 分割
    //
    // 7枚が左から少しずつ埋まっていく状態そのものが Rotash の価値なので、
    // どの枠も常に同じ比率になるよう GeometryReader で幅を明示的に割り当てる
    // （HStack の柔軟なフレームだけに頼ると、内部コンテンツの都合で崩れうるため）。

    private func grid(week: RotashWeek) -> some View {
        GeometryReader { geometry in
            // 通常は 7 枠だが、週の途中で始めた初回だけ枠数が減る。
            let count = max(week.slots.count, 1)
            let spacing: CGFloat = 1
            let cellWidth = (geometry.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let sorted = week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })
            HStack(spacing: spacing) {
                ForEach(sorted) { slot in
                    cell(slot: slot, week: week)
                        .frame(width: cellWidth, height: geometry.size.height)
                        .clipped()
                }
            }
            // 縦の画面（Memories など）で作品を同じ形に描けるよう、7枠の週で実際の1枠の形を覚えておく。
            .onAppear {
                if count == 7 { WorkShape.recordLandscapeCell(width: cellWidth, height: geometry.size.height) }
            }
            .onChange(of: geometry.size) { _, _ in
                if count == 7 { WorkShape.recordLandscapeCell(width: cellWidth, height: geometry.size.height) }
            }
            .overlay(alignment: .topLeading) {
                // 撮る間だけ、今日の枠にライブビューを出す。ピンチで横に広げられる。
                if let activeDay, let index = sorted.firstIndex(where: { $0.dayIndex == activeDay }) {
                    let cellCenterX = CGFloat(index) * (cellWidth + spacing) + cellWidth / 2
                    expandedLive(day: activeDay,
                                 frame: liveFrame(cellCenterX: cellCenterX, cellWidth: cellWidth, area: geometry.size),
                                 cellCenterX: cellCenterX,
                                 cellWidth: cellWidth)
                }
            }
            .overlay(alignment: .trailing) {
                // シャッターなどは、広げた画面ではなく7分割の右端に置く（画面が細いときも押せるように）。
                // 丸より上の空いた所の真ん中に来るようにする（日曜は丸とシャッターが同じ右端に来るため）。
                if let activeDay {
                    shootControls(day: activeDay)
                        .padding(.trailing, 16)
                        .padding(.bottom, ReverseBadge.placement(in: CGSize(width: cellWidth,
                                                                            height: geometry.size.height)).diameter
                                 + ReverseBadge.bottomInset)
                }
            }
            // 指でつまむように縮めると元の枠に近づき、広げると画面いっぱいに近づく。
            // どこから始めてもよいように、7分割全体で受ける（タップや長押しはそのまま枠に届く）。
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        guard activeDay != nil, cellWidth > 0 else { return }
                        let base = pinchBaseScale ?? liveScale
                        if pinchBaseScale == nil { pinchBaseScale = base }
                        let widest = max(1, geometry.size.width / cellWidth)
                        liveScale = min(widest, max(1, base * value.magnification))
                    }
                    .onEnded { _ in pinchBaseScale = nil }
            )
        }
        .background(Palette.background)
    }

    private func cell(slot: Slot, week: RotashWeek) -> some View {
        let day = slot.dayIndex
        let isActive = activeDay == day
        let shootable = app.canShoot(dayIndex: day)
        // 未来の枠は担当者を出さない。空いた枠だけが見えている状態を保つ。
        let assignee = app.revealedAssignee(forDay: day)
        let isToday = day == app.todayIndex && !week.isFinished

        let state = week.state(of: slot)

        return ZStack {
            if isActive {
                // 撮影中／撮り直し中のライブビューは、この枠を広げた `expandedLive` に出す
                // （カメラの映像は1か所にしか置けないので、ここには出さない）。
                Palette.surfaceDeep
            } else if slot.isFilled {
                // 元の写真（約1200万画素）をそのまま7枚読むとメモリを大きく使うので、
                // 枠の高さに足りる大きさに縮めて読む（720pt → 3倍の画面で 2160px）。
                // 長押しすると裏（撮るときシャッター側に映っていた方）に裏返る。
                FlipCard(flipped: flippedDays.contains(day) && slot.hasReverse) {
                    PhotoImageView(slot: slot, maxPixel: 720)
                } back: {
                    PhotoImageView(reverseOf: slot, maxPixel: 720)
                }
            } else {
                Palette.surface
            }

            // 撮られないまま終わった日。エラーでも欠席でもなく、
            // 「その日には写真がなかった」という作品上の状態として静かに置いておく。
            if state == .noShot {
                Text("—")
                    .rotashLabel(13, color: Palette.faint, tracking: 0)
            }

            // 曜日と名前は枠の上、裏の丸は枠の下に置き、真ん中（写真の主役が来るところ）を空けておく。
            // 共有画像（WorkExporter）も同じ並びにしてある。
            LinearGradient(colors: [.black.opacity(0.55), .clear],
                           startPoint: .top,
                           endPoint: UnitPoint(x: 0.5, y: 0.3))
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    Text(RotashDay.label(for: day))
                        .rotashLabel(10,
                                     color: slot.isFilled ? Palette.text : (isActive ? Palette.text : Palette.dim),
                                     tracking: 1.4)
                    if let assignee {
                        Text(assignee.name.uppercased())
                            .rotashLabel(8, color: isActive ? Palette.live : Palette.faint, tracking: 0.8)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .padding(.top, 12)
                Spacer(minLength: 0)
            }

            if slot.isFilled, slot.hasReverse, !isActive {
                // 大きく出ていない方を丸で添える。裏返すと、丸には表が入る。
                // 細い枠は下の真ん中、横に広い枠（週の途中から始めた最初の週）は右下（ReverseBadge.placement）。
                GeometryReader { geometry in
                    let placement = ReverseBadge.placement(in: geometry.size)
                    reverseBadge(slot: slot, showsFront: flippedDays.contains(day), diameter: placement.diameter)
                        .padding(.bottom, ReverseBadge.bottomInset)
                        .padding(.trailing, placement.centered ? 0 : ReverseBadge.bottomInset)
                        .frame(width: geometry.size.width, height: geometry.size.height,
                               alignment: placement.centered ? .bottom : .bottomTrailing)
                }
            }

            if isToday {
                VStack {
                    Rectangle()
                        .fill(Palette.live)
                        .frame(height: 2)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(Rectangle().stroke(isActive ? Palette.live : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture {
            // 撮っている枠は上にライブビュー（expandedLive）が重なっていて、押すとそちらで撮る。
            guard !isActive else { return }
            if slot.isFilled {
                // 写真のある枠は、全画面で大きく見る（撮り直しは下の RETAKE から）。
                viewerSwapped = false
                withAnimation(.easeOut(duration: 0.2)) { viewerDay = day }
            } else if shootable {
                manualSelection = day
            }
        }
        // 押してすぐ離すと全画面、少し長く押すと裏返す。短すぎると、ふつうに押したつもりでも裏返る。
        .onLongPressGesture(minimumDuration: 0.3) {
            guard !isActive, slot.hasReverse else { return }
            toggleFlip(day)
        }
    }

    /// その日の枠を裏返す（長押し、または枠の下の丸を押す）。
    private func toggleFlip(_ day: Int) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.45)) {
            if flippedDays.contains(day) { flippedDays.remove(day) } else { flippedDays.insert(day) }
        }
    }

    /// 枠の下に添える丸。撮るときのシャッターの丸と同じ形。押すとその枠が裏返る（長押しと同じ）。
    private func reverseBadge(slot: Slot, showsFront: Bool, diameter: CGFloat) -> some View {
        Button { toggleFlip(slot.dayIndex) } label: {
            PhotoImageView(filename: showsFront ? slot.photoFilename : slot.reversePhotoFilename,
                           remoteURL: showsFront ? slot.photoURL : slot.reversePhotoURL,
                           maxPixel: 240)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 全画面で見る

    /// 写真のある枠を押したときの全画面。写真そのものの形で大きく出し、右下の丸（もう一方のカメラ）を押すと入れ替わる。
    /// 背景か「×」を押すと閉じる。
    private func photoViewer(_ slot: Slot) -> some View {
        let day = slot.dayIndex
        // 枠を裏返している日は裏から見せる。丸を押すか写真を長押しすると、さらに入れ替わる。
        let showsReverse = slot.hasReverse && (flippedDays.contains(day) != viewerSwapped)
        return GeometryReader { geometry in
            // 写真は画面の高さいっぱい（上下の端まで）。丸はその高さの 1/3。
            let fullHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            let diameter = (fullHeight / 3).rounded()
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture { closeViewer() }

                // 1つの PhotoImageView のまま中身だけ替える（作り直すと、入れ替えるたびに一瞬暗くなる）。
                // 読む大きさは画面に出る大きさまで（4:3 を画面の高さいっぱいに出すとき、横は高さの 4/3）。
                PhotoImageView(filename: showsReverse ? slot.reversePhotoFilename : slot.photoFilename,
                               remoteURL: showsReverse ? slot.reversePhotoURL : slot.photoURL,
                               maxPixel: (fullHeight * 4 / 3).rounded())
                    .natural()
                .overlay(alignment: .bottomTrailing) {
                    if slot.hasReverse {
                        Button { swapViewer() } label: {
                            PhotoImageView(filename: showsReverse ? slot.photoFilename : slot.reversePhotoFilename,
                                           remoteURL: showsReverse ? slot.photoURL : slot.reversePhotoURL,
                                           maxPixel: diameter)
                            .frame(width: diameter, height: diameter)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(diameter / 8)
                    }
                }
                // 写真を長押ししても、表と裏が入れ替わる（7分割の枠と同じ）。
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.3) {
                    guard slot.hasReverse else { return }
                    swapViewer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .vertical)

                VStack {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(RotashDay.label(for: day))
                            .rotashLabel(11, color: Palette.text, tracking: 1.8)
                        if let name = app.revealedAssignee(forDay: day)?.name {
                            Text(name.uppercased())
                                .rotashLabel(10, color: Palette.dim, tracking: 0.8)
                        }
                        if let capturedAt = slot.capturedAt {
                            Text(RotashDateFormat.time.string(from: capturedAt))
                                .rotashLabel(10, color: Palette.faint, tracking: 1)
                        }
                        Spacer()
                        Button { closeViewer() } label: {
                            Text("×")
                                .rotashLabel(18, color: Palette.text, tracking: 0)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.4))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private func swapViewer() {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.2)) { viewerSwapped.toggle() }
    }

    private func closeViewer() {
        withAnimation(.easeOut(duration: 0.2)) { viewerDay = nil }
    }

    /// 撮るときの大きい画面の位置と大きさ（7分割の中の座標）。高さは枠と同じで、幅だけ liveScale で変わる。
    /// 今日の枠の真ん中に重ね、端の曜日は内側に寄せる。
    private func liveFrame(cellCenterX: CGFloat, cellWidth: CGFloat, area: CGSize) -> CGRect {
        let width = min(area.width, max(cellWidth, cellWidth * liveScale))
        let x = min(max(0, cellCenterX - width / 2), max(0, area.width - width))
        return CGRect(x: x, y: 0, width: width, height: area.height)
    }

    /// 撮る間のライブビュー。はじめは今日の枠と同じ大きさで、ピンチで横に広げられる（`liveScale`）。
    ///
    /// 広げているときは、7分割のサムネ（今日の枠）に入る範囲を線で示す。
    /// 保存する写真は、広げても縮めてもカメラの映像そのまま（サムネはその真ん中を枠の形に切り出した所）。
    /// 近くの日は広げている間だけ隠れ、撮り終わると7分割に戻る。押すと撮る。
    ///
    /// 裏（もう一方のカメラ）は、今日の枠の下（撮ったあと裏の丸が添えられる所）に同じ大きさの丸で出す。
    /// 広げても縮めても丸は変わらない。撮るときに見ている丸が、そのまま枠の下の丸になる。
    private func expandedLive(day: Int, frame: CGRect, cellCenterX: CGFloat, cellWidth: CGFloat) -> some View {
        // 横持ちの写真は横長（frameAspect は「短い辺 ÷ 長い辺」）。
        let badge = ReverseBadge.placement(in: CGSize(width: cellWidth, height: frame.height))
        let badgeCenterX = badge.centered
            ? cellCenterX
            : cellCenterX + cellWidth / 2 - ReverseBadge.bottomInset - badge.diameter / 2
        let region = ThumbnailGuide.thumbnailRegion(view: frame.size,
                                                    photoAspect: 1 / max(0.3, camera.frameAspect),
                                                    cellAspect: cellWidth / max(1, frame.height))
        return ZStack {
            liveContent
            if frame.width > cellWidth + 1 {
                ThumbnailGuide(region: region)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipped()
        .overlay(Rectangle().stroke(Palette.live, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { capture(day: day) }
        .overlay(alignment: .bottom) {
            // 丸を押すと表と裏が入れ替わる（FLIP と同じ）。
            Button { camera.switchCamera() } label: {
                ReverseLiveCircle(camera: camera, diameter: badge.diameter)
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)
            .padding(.bottom, ReverseBadge.bottomInset)
            // 撮ったあと今日の枠に丸が添えられる所（細い枠は下の真ん中、広い枠は右下）に合わせる。
            .offset(x: badgeCenterX - frame.minX - frame.width / 2)
        }
        .offset(x: frame.minX)
    }

    /// 7分割の右端に縦に並べる、撮るための操作。上から SHOOT / RETAKE の表示、シャッター、FLIP。
    private func shootControls(day: Int) -> some View {
        VStack(spacing: 10) {
            Text(isRetake ? "RETAKE\(retakeCountdown(for: day))" : "SHOOT")
                .rotashLabel(9, color: Palette.live, tracking: 3)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.5))
            ShutterButton(diameter: 64, isBusy: isCapturing) { capture(day: day) }
            flipButton
        }
        // ボタンのすきまを押したときに、下にある枠が選ばれないように受け止める。
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    @ViewBuilder
    private var liveContent: some View {
        switch camera.status {
        case .ready:
            if camera.isDual, let layer = camera.livePreviewLayer(for: camera.position) {
                // 同時撮影では、カメラごとのレイヤーで映す（ふつうのプレビューはつなげない）。
                LiveLayerView(layer: layer)
            } else {
                CameraPreview(controller: camera)
            }
        case .denied:
            ZStack {
                Palette.surfaceDeep
                Text("カメラの\n許可が\n必要です")
                    .rotashLabel(9, color: Palette.dim, tracking: 0.5)
                    .multilineTextAlignment(.center)
            }
        case .unavailable:
            ZStack {
                Palette.surfaceDeep
                Text("NO\nCAMERA")
                    .rotashLabel(9, color: Palette.dim)
                    .multilineTextAlignment(.center)
            }
        case .idle:
            Palette.surfaceDeep
        }
    }

    // MARK: - 撮影操作

    // 完成したかどうかは7枚の写真そのもの（と SHARE ボタンの有無）で伝わるので、
    // ここでは撮影ボタン以外のテキストは出さない。
    // 今日の担当が誰かも、各枠に既に名前が出ているので改めて言葉にしない。
    @ViewBuilder
    private func bottomControl(week: RotashWeek) -> some View {
        if activeDay != nil {
            // 撮る間の操作（シャッター・FLIP）は、広げたライブビューの右端に出している（shootControls）。
            EmptyView()
        } else if let window = app.retakeWindow(now: now) {
            // 撮った直後。写真を見て「事故った」と思ったら、ここから撮り直せる。
            // 押すとその枠にライブビューが戻る。時間が切れたら黙って消える。
            Button { manualSelection = window.dayIndex } label: {
                Text("RETAKE\(retakeCountdown(for: window.dayIndex))")
                    .rotashLabel(10, color: Palette.text, tracking: 2.4)
                    .frame(height: 46)
                    .padding(.horizontal, 18)
                    .background(Color.black.opacity(0.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
    }

    /// 撮り直せる残り秒数（「  24」のような形）。撮り直しの対象でなければ空。
    /// 1桁になっても幅が変わらないよう2桁ぶんに揃える（等幅フォントなので文字が揺れない）。
    private func retakeCountdown(for day: Int) -> String {
        guard let slot = week?.slot(at: day),
              app.canShoot(dayIndex: day, now: now),
              let deadline = app.retakeDeadline(for: slot),
              now < deadline
        else { return "" }
        let window = Int(RotashFeatureFlags.retakeWindowSeconds)
        let seconds = min(window, max(0, Int(deadline.timeIntervalSince(now).rounded(.up))))
        return seconds < 10 ? "   \(seconds)" : "  \(seconds)"
    }

    private var flipButtonWidth: CGFloat { 62 }

    @ViewBuilder
    private var flipButton: some View {
        if camera.status == .ready {
            Button { camera.switchCamera() } label: {
                Text("FLIP")
                    .rotashLabel(10, color: Palette.text, tracking: 1.8)
                    .frame(width: flipButtonWidth, height: 46)
                    .background(Color.black.opacity(0.5))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)
        } else {
            Color.clear.frame(width: flipButtonWidth, height: 1)
        }
    }

    private func capture(day: Int) {
        guard !isCapturing, app.canShoot(dayIndex: day) else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        // 表は大きい画面（枠）側、裏は丸の側。どちらが内カメかは FLIP しだい。
        let front = camera.position == .front
        let reverseFront = camera.reversePosition == .front
        camera.captureBoth(fallbackSeed: day) { main, reverse in
            Task { @MainActor in
                self.flashOpacity = 0.85
                withAnimation(.easeOut(duration: 0.28)) { self.flashOpacity = 0 }
                if let main {
                    self.app.attachPhoto(main, toDay: day, front: front,
                                         reverse: reverse, reverseFront: reverseFront)
                    self.manualSelection = nil
                    self.flippedDays.remove(day)
                }
                // 撮り直しの残り秒数をここから数え始める。撮った時刻（attachPhoto の中で決まる）より
                // 前に合わせると、残りが一瞬 31 秒に見えるので、保存が終わってから合わせる。
                self.now = Date()
                self.isCapturing = false
            }
        }
    }

    private func syncCamera() {
        if activeDay != nil {
            camera.start()
        } else {
            camera.stop()
        }
    }
}
