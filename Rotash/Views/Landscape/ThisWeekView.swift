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
                    if week.isFinished {
                        finished(week: week)
                    } else {
                        grid(week: week)
                    }
                }
                .overlay(alignment: .bottom) { bottomControl(week: week) }
            }

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear { syncCamera() }
        .onDisappear { camera.stop() }
        .onChange(of: activeDay) { _, _ in syncCamera() }
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
            Text("THIS WEEK")
                .rotashLabel(12, color: Palette.text, tracking: 3.4)
            Text(week.dateRange)
                .rotashLabel(10, color: Palette.faint)
            Text("\(week.filledCount) / \(week.slots.count)")
                .rotashLabel(10, color: Palette.dim, tracking: 1.4)
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

    /// 進行中は画面を埋め尽くし、完成形は余白の中に置く。
    /// 見え方が変わることそのもので「終わった」が伝わるので、
    /// 「完成しました！」とは書かない。
    ///
    /// ただし、終わったことを伝えすぎてもいけない。
    /// 初期のグループは「◯◯までの7日間」という出来事を理由に立ち上がり、
    /// その出来事は7日目に終わる。出来事の終わりと作品の完成が同じ日に重なると
    /// 二重の終止符になり、翌週に戻ってこなくなる。
    /// だから作品を単独では見せず、**これまでの積み重ねの上に1本載った**形にする。
    @ViewBuilder
    private func finished(week: RotashWeek) -> some View {
        VStack(spacing: 12) {
            if let archive = app.group?.archive, !archive.isEmpty {
                VStack(spacing: 2) {
                    ForEach(Array(archive.prefix(4))) { past in
                        WeekThumbnailStrip(week: past, height: 9)
                            .opacity(0.45)
                    }
                }
                .padding(.horizontal, 40)
            }

            grid(week: week)
                .padding(.horizontal, 28)

            titleArea(week: week)
        }
        .padding(.vertical, 12)
    }

    /// その週の一行。
    ///
    /// 書けるのは **7枚目を撮った本人だけ**。全員が書けるようにすると、
    /// それはタイトルではなくコメント欄になる。
    /// 空のままでも作品は成立するので、催促はしない。
    @ViewBuilder
    private func titleArea(week: RotashWeek) -> some View {
        if let title = week.title, !title.isEmpty {
            Text(title)
                .font(Typo.title(16))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .padding(.horizontal, 28)

        } else if app.titlableWeek?.id == week.id, app.retakeWindow(now: now) == nil {
            // 撮り直せるあいだは写真がまだ確定していないので、名前をつける欄は出さない
            // （画面下の RETAKE ボタンと重なるのも避けられる）。
            HStack(spacing: 12) {
                TextField("", text: $draftTitle,
                          prompt: Text("この1週間に名前をつける"))
                    .textFieldStyle(.plain)
                    .font(Typo.title(15))
                    .foregroundStyle(Palette.text)
                    .submitLabel(.done)
                    .onSubmit { commitTitle(for: week) }

                Button("つける") { commitTitle(for: week) }
                    .font(Typo.label(11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(draftTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? Palette.faint : Palette.live)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
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
            .overlay(alignment: .topLeading) {
                // 撮る間だけ、今日の枠を写真と同じ横長の形に広げてライブビューを出す。
                if let activeDay, let index = sorted.firstIndex(where: { $0.dayIndex == activeDay }) {
                    expandedLive(day: activeDay,
                                 cellCenterX: CGFloat(index) * (cellWidth + spacing) + cellWidth / 2,
                                 cellWidth: cellWidth,
                                 area: geometry.size)
                }
            }
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
                if slot.isFilled, slot.hasReverse, !isActive {
                    // 大きく出ていない方を丸で添える。裏返すと、丸には表が入る。
                    reverseBadge(slot: slot, showsFront: flippedDays.contains(day))
                        .padding(.bottom, ReverseBadge.bottomInset)
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
            if isActive {
                capture(day: day)
            } else if shootable {
                manualSelection = day
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !isActive, slot.hasReverse else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeInOut(duration: 0.45)) {
                if flippedDays.contains(day) { flippedDays.remove(day) } else { flippedDays.insert(day) }
            }
        }
    }

    /// 枠の下に添える丸。撮るときのシャッターの丸と同じ形。
    private func reverseBadge(slot: Slot, showsFront: Bool) -> some View {
        GeometryReader { geometry in
            let diameter = geometry.size.width * ReverseBadge.widthRatio
            Group {
                if showsFront {
                    PhotoImageView(slot: slot, maxPixel: 240)
                } else {
                    PhotoImageView(reverseOf: slot, maxPixel: 240)
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .frame(width: geometry.size.width, height: diameter)
        }
        .aspectRatio(1 / ReverseBadge.widthRatio, contentMode: .fit)
        .allowsHitTesting(false)
    }

    /// 撮る間だけ、今日の枠を写真と同じ横長の形（枠と同じ高さ）に広げたライブビュー。
    ///
    /// 保存される写真の範囲をそのまま映し、サムネ（今日の枠）に入る範囲を線で示す。
    /// 今日の枠の真ん中に重ねるので、線はちょうど今日の枠の位置に来る（端の曜日は内側に寄せる）。
    /// 近くの日は撮る間だけ隠れ、撮り終わると7分割に戻る。押すと撮る。
    ///
    /// 裏（もう一方のカメラ）は、今日の枠の下（撮ったあと裏の丸が添えられる所）に同じ大きさの丸で、
    /// シャッターは右端に置く。撮るときに見ている丸が、そのまま枠の下の丸になる。
    private func expandedLive(day: Int, cellCenterX: CGFloat, cellWidth: CGFloat, area: CGSize) -> some View {
        let frameAspect = max(0.3, camera.frameAspect)
        let width = min(area.width, area.height / frameAspect)
        let x = min(max(0, cellCenterX - width / 2), max(0, area.width - width))
        let region = ThumbnailGuide.centerCrop(imageAspect: width / max(1, area.height),
                                               cellAspect: cellWidth / max(1, area.height))
        let badgeDiameter = cellWidth * ReverseBadge.widthRatio
        return ZStack {
            liveContent
            ThumbnailGuide(region: region)
        }
        .frame(width: width, height: area.height)
        .clipped()
        .overlay(Rectangle().stroke(Palette.live, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { capture(day: day) }
        .overlay(alignment: .bottom) {
            // 丸を押すと表と裏が入れ替わる（FLIP と同じ）。
            Button { camera.switchCamera() } label: {
                ReverseLiveCircle(camera: camera, diameter: badgeDiameter)
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)
            .padding(.bottom, ReverseBadge.bottomInset)
            // 広げた画面の中での、今日の枠の真ん中に合わせる。
            .offset(x: cellCenterX - x - width / 2)
        }
        .overlay(alignment: .trailing) {
            // 丸より上の空いた所の真ん中に置く（端の曜日では、丸とシャッターが同じ右端に来るため）。
            shootControls(day: day)
                .padding(.trailing, 16)
                .padding(.bottom, badgeDiameter + ReverseBadge.bottomInset)
        }
        .offset(x: x)
    }

    /// ライブビューの右端に縦に並べる、撮るための操作。上から SHOOT / RETAKE の表示、シャッター、FLIP。
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
