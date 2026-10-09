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
    /// パノラマで撮るときの状態（試験中）。
    @StateObject private var panorama = PanoramaShooter()
    @State private var flashOpacity: Double = 0
    @State private var draftTitle = ""
    /// 撮り直せる残り時間を数えるための「いま」。撮り直せるあいだだけ進める。
    /// 表示を描き直すきっかけとして使う。撮れるかどうかの判定そのものは常に本物の現在時刻で行う。
    @State private var now = Date()
    /// 撮り直しの残り秒数を数える時計。`body` の中で作ると描き直すたびに作り直されて刻まなくなるので、
    /// プロパティとして持つ（ThisWeekView 自体が作り直されたときだけ新しくなる）。
    private let clock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    /// 設定画面で変えた Rotash レンズの広げ具合。
    @AppStorage(RotashLens.storageKey) private var storedLensWidening = RotashFeatureFlags.lensWidening
    @AppStorage(RotashLens.frontStorageKey) private var storedFrontLensWidening = RotashFeatureFlags.frontLensWidening
    @AppStorage(RotashLens.frontModeKey) private var storedFrontLensMode = RotashFeatureFlags.frontLensMode.rawValue
    @AppStorage(RotashLens.frontReachKey) private var storedFrontLensReach = RotashFeatureFlags.frontLensReach
    @AppStorage(RotashLens.frontBlurKey) private var storedFrontLensBlur = RotashFeatureFlags.frontLensBlurFill

    /// 内カメのレンズの選び方（方式・縮める割合・押し込む横幅）。
    private var frontLens: RotashLens.FrontOptions {
        RotashLens.resolveFront(mode: storedFrontLensMode,
                                widening: storedFrontLensWidening,
                                reach: storedFrontLensReach,
                                blur: storedFrontLensBlur)
    }

    /// 保存済みの写真にかけるレンズ（撮ったカメラで方式が変わる）。
    private func lens(for slot: Slot) -> RotashLens.Setting {
        RotashLens.setting(for: slot,
                           back: RotashLens.resolve(stored: storedLensWidening),
                           front: frontLens)
    }

    /// ライブビューにかけるレンズ。いま使っているカメラで決まる（撮ったあとの表示と同じになる）。
    private var liveLens: RotashLens.Setting {
        RotashLens.setting(isFront: camera.position == .front,
                           back: RotashLens.resolve(stored: storedLensWidening),
                           front: frontLens)
    }

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
        .onChange(of: camera.panoramaFrameCount) { _, count in
            if panorama.isRecording, count >= CameraController.panoramaMaxFrames, let day = activeDay {
                finishPanorama(day: day)
            }
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
            HStack(spacing: spacing) {
                ForEach(week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })) { slot in
                    cell(slot: slot, week: week)
                        .frame(width: cellWidth, height: geometry.size.height)
                        .clipped()
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
                // 撮影中／撮り直し中は自分の写真より優先してライブビューを見せる。
                liveContent
            } else if slot.isFilled {
                // ライブビューと同じレンズをかける。撮るときに見えた絵のまま枠に残る。
                // 元の写真（約1200万画素）をそのまま7枚読むとメモリを大きく使うので、
                // 枠の高さに足りる大きさに縮めて読む（720pt → 3倍の画面で 2160px）。
                PhotoImageView(slot: slot, maxPixel: 720, lens: lens(for: slot))
            } else {
                Palette.surface
            }

            // 撮られないまま終わった日。エラーでも欠席でもなく、
            // 「その日には写真がなかった」という作品上の状態として静かに置いておく。
            if state == .noShot {
                Text("—")
                    .rotashLabel(13, color: Palette.faint, tracking: 0)
            }

            LinearGradient(colors: [.clear, .black.opacity(0.55)],
                           startPoint: UnitPoint(x: 0.5, y: 0.62),
                           endPoint: .bottom)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
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
                .padding(.bottom, 10)
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
                shutter(day: day)
            } else if shootable {
                manualSelection = day
            }
        }
    }

    @ViewBuilder
    private var liveContent: some View {
        switch camera.status {
        case .ready:
            if liveLens.isActive, camera.supportsLensPreview {
                LensCameraPreview(controller: camera, setting: liveLens)
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
        if let activeDay {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text(panorama.status(frameCount: camera.panoramaFrameCount)
                         ?? (isRetake ? "RETAKE\(retakeCountdown(for: activeDay))" : "SHOOT"))
                        .rotashLabel(9, color: Palette.live, tracking: 3)
                    if camera.supportsLensPreview, camera.status == .ready {
                        PanoramaToggle(shooter: panorama)
                            .background(Color.black.opacity(0.5))
                            .disabled(isCapturing)
                    }
                }

                // FLIP は狭い枠の隅だと押しづらいので、シャッターの横に置いて
                // 指の届く大きさ（44pt 以上）にしている。
                // 反対側に同じ幅の余白を入れて、シャッターは中央のままにする。
                HStack(spacing: 20) {
                    flipButton
                    shutterButton
                    modeButton
                }
            }
            .padding(.bottom, 12)
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

    /// 内カメの方式を撮りながら切り替えるボタン（`LensModeButton`）。
    @ViewBuilder
    private var modeButton: some View {
        if camera.status == .ready {
            LensModeButton(width: flipButtonWidth, isFront: camera.position == .front, dimsBackground: true)
                .disabled(isCapturing)
        } else {
            Color.clear.frame(width: flipButtonWidth, height: 1)
        }
    }

    private var shutterButton: some View {
        Button { shutter(day: activeDay ?? 0) } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 54, height: 54)
                Circle()
                    .fill(Color.white)
                    .frame(width: 42, height: 42)
                    .opacity(isCapturing && !panorama.isRecording ? 0.35 : 1)
                if panorama.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Palette.live)
                        .frame(width: 18, height: 18)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isCapturing && !panorama.isRecording)
    }

    /// シャッター。パノラマがオンなら、1回目でため始め、2回目（または上限）でやめてつなぐ。
    private func shutter(day: Int) {
        guard panorama.isArmed else { return capture(day: day) }
        if panorama.isRecording {
            finishPanorama(day: day)
        } else {
            guard !isCapturing, app.canShoot(dayIndex: day) else { return }
            isCapturing = true
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            panorama.start(camera: camera)
        }
    }

    private func finishPanorama(day: Int) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let front = camera.position == .front
        panorama.finish(camera: camera) { data in
            self.isCapturing = false
            guard let data else { return }
            self.flashOpacity = 0.85
            withAnimation(.easeOut(duration: 0.28)) { self.flashOpacity = 0 }
            self.app.attachPhoto(data, toDay: day, front: front)
            self.manualSelection = nil
            self.now = Date()
        }
    }

    private func capture(day: Int) {
        guard !isCapturing, app.canShoot(dayIndex: day) else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        camera.capture(fallbackSeed: day) { data in
            Task { @MainActor in
                self.flashOpacity = 0.85
                withAnimation(.easeOut(duration: 0.28)) { self.flashOpacity = 0 }
                if let data {
                    self.app.attachPhoto(data, toDay: day, front: self.camera.position == .front)
                    self.manualSelection = nil
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
