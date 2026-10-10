import Combine
import SwiftUI
import UIKit

/// 縦持ちで撮る画面（試験中。`RotashFeatureFlags.allowsPortraitShooting`）。
///
/// # 表と裏を同時に撮る
///
/// 大きい画面に映っている方が「表」（7分割のサムネと共有画像に出る）、
/// シャッターの丸に映っている方が「裏」（枠を長押ししたとき・週が終わって作品を裏返したときに見える）。
/// 最初は表が外カメ、裏が内カメで、FLIP で入れ替えられる。どちらが内カメかでは決めない。
/// シャッターを押すと、表と裏を同じ瞬間に撮る（`CameraController.captureBoth`）。
///
/// # 何を見せるか
///
/// 大きい画面には、保存される写真の範囲をそのまま映し、7分割の枠（サムネ）に入る範囲を線で示す。
/// 枠の大きさのままだと、シャッターを「カメラ」にするには狭すぎるため。
/// 上には今週の7分割を小さく出し、前の日の写真を見ながら撮れるようにしておく
/// （「前の日の写真に返して撮る」関係を、縦の撮影画面でも保つ）。未来の担当者は出さない。
struct PortraitShootView: View {

    @EnvironmentObject private var app: AppViewModel
    /// 最初は表（大きい画面）が外カメ、裏（シャッターの丸）が内カメ。
    @StateObject private var camera = CameraController(position: .back)
    /// 撮ったあとの表示で、裏を大きく出しているか（丸を押すと入れ替わる）。
    @State private var showsReverseLarge = false
    /// 撮ったあとに大きく出している写真の「幅 ÷ 高さ」。読めるまでは nil。
    /// 横持ちで撮った写真は横長なので、いまのカメラの形（frameAspect）とは限らない。
    @State private var capturedAspect: CGFloat?

    @State private var isCapturing = false
    @State private var flashOpacity: Double = 0
    /// 撮ったあと、撮り直すためにライブビューへ戻しているか。
    @State private var retaking = false
    /// 撮り直しの残り秒数を数えるための「いま」。ThisWeekView と同じ考え方。
    @State private var now = Date()
    private let clock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var day: Int { app.todayIndex }
    private var slot: Slot? { app.group?.currentWeek.slot(at: day) }
    private var isFilled: Bool { slot?.isFilled ?? false }

    /// ライブビューを出しているか。まだ撮っていないか、撮り直し中のときだけ。
    private var showsLive: Bool {
        app.canShoot(dayIndex: day) && (!isFilled || retaking)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.background.ignoresSafeArea()

                if geometry.size.width > geometry.size.height {
                    // 横にしてしまったとき。この画面は縦で撮るためのもの。
                    VStack(spacing: 18) {
                        Text("縦にして撮ってください")
                            .rotashLabel(12, color: Palette.text, tracking: 0.6)
                        closeButton
                    }
                } else {
                    VStack(spacing: 0) {
                        topBar
                        if let week = app.group?.currentWeek {
                            WeekThumbnailStrip(week: week, height: 44)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                        }
                        mainPane(cellAspect: Self.cellAspect(portraitSize: geometry.size))
                            .frame(maxHeight: .infinity)
                        bottomControl
                    }
                }

                Color.white
                    .opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear { syncCamera() }
        .onDisappear { camera.stop() }
        .onChange(of: showsLive) { _, _ in syncCamera() }
        .onReceive(clock) { date in
            if let deadline = app.latestRetakeDeadline, now <= deadline { now = date }
        }
    }

    // MARK: - 上

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            closeButton
            Spacer()
            Text(RotashDay.label(for: day))
                .rotashLabel(11, color: Palette.text, tracking: 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var closeButton: some View {
        Button { app.activeSheet = nil } label: {
            Text(isFilled && !showsLive ? "完了" : "とじる")
                .rotashLabel(11, color: Palette.text, tracking: 1.6)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 大きい画面

    /// 撮る前はライブビュー、撮ったあとはその日の写真。どちらも保存される写真の範囲をそのまま見せ、
    /// サムネに入る範囲を線で示す。
    private func mainPane(cellAspect: CGFloat) -> some View {
        GeometryReader { area in
            let aspect = max(0.3, camera.frameAspect)
            let width = min(area.size.width - 40, area.size.height * aspect)
            let height = width / aspect
            ZStack {
                if showsLive {
                    liveContent
                    ThumbnailGuide(region: ThumbnailGuide.centerCrop(imageAspect: aspect, cellAspect: cellAspect))
                } else if let slot, slot.isFilled {
                    capturedContent(slot, aspect: aspect, cellAspect: cellAspect)
                } else {
                    Palette.surface
                }
            }
            .frame(width: width, height: height)
            .clipped()
            .overlay(Rectangle().stroke(showsLive ? Palette.live : Color.clear, lineWidth: 2))
            .frame(width: area.size.width, height: area.size.height)
        }
    }

    /// 撮ったあと。表を大きく、裏を右下の丸に出す。丸を押すと大小が入れ替わる（裏はいつでも見られる）。
    @ViewBuilder
    private func capturedContent(_ slot: Slot, aspect: CGFloat, cellAspect: CGFloat) -> some View {
        let large = showsReverseLarge && slot.hasReverse
        ZStack(alignment: .bottomTrailing) {
            if large {
                PhotoImageView(reverseOf: slot, maxPixel: 1080)
            } else {
                // 写真そのものの形で真ん中に出し、サムネの線もその形から作る。
                PhotoImageView(slot: slot, maxPixel: 1080)
                    .natural()
                    .onLoad { size in capturedAspect = size.width / max(1, size.height) }
                    .overlay {
                        ThumbnailGuide(region: ThumbnailGuide.centerCrop(imageAspect: capturedAspect ?? aspect,
                                                                         cellAspect: cellAspect))
                    }
                    // 外の ZStack は丸のために右下そろえなので、写真は大きい画面の真ん中に置き直す。
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if slot.hasReverse {
                Button { showsReverseLarge.toggle() } label: {
                    Group {
                        if large {
                            PhotoImageView(slot: slot, maxPixel: 300)
                        } else {
                            PhotoImageView(reverseOf: slot, maxPixel: 300)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(14)
            }
        }
    }

    /// 横向きにしたときの1枠の「幅 ÷ 高さ」。
    /// 横向きの画面は、縦向きの高さが横幅に、横幅が高さになる。
    /// その横幅を7つに割り、高さから見出しの分（約44pt）を引いた形が1枠。
    static func cellAspect(portraitSize: CGSize) -> CGFloat {
        let landscapeWidth = max(portraitSize.height, 1)
        let landscapeHeight = max(portraitSize.width - 44, 1)
        return (landscapeWidth / 7) / landscapeHeight
    }

    @ViewBuilder
    private var liveContent: some View {
        switch camera.status {
        case .ready:
            // 大きい画面は、保存される写真の範囲をそのまま映す（サムネに入る範囲は線で示す）。
            if camera.isDual, let layer = camera.livePreviewLayer(for: camera.position) {
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

    // MARK: - 下

    @ViewBuilder
    private var bottomControl: some View {
        VStack(spacing: 10) {
            if showsLive {
                Text(isFilled ? "RETAKE\(retakeCountdown)" : "SHOOT")
                    .rotashLabel(9, color: Palette.live, tracking: 3)
                HStack(spacing: 24) {
                    flipButton
                    CameraShutter(camera: camera, diameter: 96, isBusy: isCapturing) { capture() }
                    // FLIP と左右をそろえ、シャッターを真ん中に置く。
                    Color.clear.frame(width: 62, height: 1)
                }
            } else if isFilled, app.canShoot(dayIndex: day, now: now) {
                // 撮った直後。事故ったと思ったら、ここから撮り直せる。
                Button { retaking = true } label: {
                    Text("RETAKE\(retakeCountdown)")
                        .rotashLabel(10, color: Palette.text, tracking: 2.4)
                        .frame(height: 46)
                        .padding(.horizontal, 18)
                        .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if isFilled {
                Text("→ 横にして見る")
                    .rotashLabel(10, color: Palette.faint, tracking: 1.2)
                    .frame(height: 46)
            } else {
                Text("今日は撮れません")
                    .rotashLabel(10, color: Palette.faint, tracking: 1.2)
                    .frame(height: 46)
            }
        }
        .frame(height: 150)
        .padding(.bottom, 8)
    }

    /// 撮り直せる残り秒数（「  24」のような形）。撮り直しの対象でなければ空。
    private var retakeCountdown: String {
        guard let slot,
              app.canShoot(dayIndex: day, now: now),
              let deadline = app.retakeDeadline(for: slot),
              now < deadline
        else { return "" }
        let window = Int(RotashFeatureFlags.retakeWindowSeconds)
        let seconds = min(window, max(0, Int(deadline.timeIntervalSince(now).rounded(.up))))
        return seconds < 10 ? "   \(seconds)" : "  \(seconds)"
    }

    @ViewBuilder
    private var flipButton: some View {
        if camera.status == .ready {
            Button { camera.switchCamera() } label: {
                Text("FLIP")
                    .rotashLabel(10, color: Palette.text, tracking: 1.8)
                    .frame(width: 62, height: 46)
                    .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)
        } else {
            Color.clear.frame(width: 62, height: 1)
        }
    }

    // MARK: - 撮影

    /// 表と裏を撮る。表は大きい画面側、裏はシャッター側（どちらが内カメかは FLIP しだい）。
    private func capture() {
        guard !isCapturing, app.canShoot(dayIndex: day) else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let target = day
        let front = camera.position == .front
        let reverseFront = camera.reversePosition == .front

        camera.captureBoth(fallbackSeed: target) { main, reverse in
            Task { @MainActor in
                self.flashOpacity = 0.85
                withAnimation(.easeOut(duration: 0.28)) { self.flashOpacity = 0 }
                if let main {
                    self.app.attachPhoto(main, toDay: target, front: front,
                                         reverse: reverse, reverseFront: reverseFront)
                    self.retaking = false
                    self.showsReverseLarge = false
                }
                // 撮った時刻（attachPhoto の中で決まる）のあとで合わせる。先だと残りが一瞬 31 に見える。
                self.now = Date()
                self.isCapturing = false
            }
        }
    }

    private func syncCamera() {
        if showsLive {
            camera.start()
        } else {
            camera.stop()
        }
    }
}
