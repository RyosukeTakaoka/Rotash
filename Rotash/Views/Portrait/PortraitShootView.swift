import Combine
import SwiftUI
import UIKit

/// 縦持ちで撮る画面（試験中。`RotashFeatureFlags.allowsPortraitShooting`）。
///
/// # なぜ縦で撮るのか
///
/// 7分割の枠は縦に細長い。スマホを横にして撮ると、カメラの写す範囲は横長なので、
/// 枠に入るのは写真の横幅の2割ほどしかない。撮る瞬間だけ縦にすれば、
/// カメラの向きと枠の向きがそろい、**曲げずに**横も縦も約1.3倍広く写る。
/// さらに横向きの7分割と同じ疑似広角（`RotashLens`）をかけるので、見え方は横で撮った写真とそろう。
///
/// # 何を見せるか
///
/// ライブビューは全画面にしない（IMPLEMENTATION_PLAN の NEVER「カメラ全画面」）。
/// 横向きの7分割と同じ形の枠の中にだけ出し、左に前日の写真、右に翌日の枠を並べる。
/// 撮る人が「前の日の写真に返して撮る」関係は、これで縦でも保たれる。
/// 7枚すべては見せない（縦では今週の作品を見せないという入口の約束を崩さないため）。
struct PortraitShootView: View {

    @EnvironmentObject private var app: AppViewModel
    /// 縦で撮るのは自撮りが多いので、前面カメラから始める。
    @StateObject private var camera = CameraController(position: .front)

    @State private var isCapturing = false
    @State private var flashOpacity: Double = 0
    /// 撮ったあと、撮り直すためにライブビューへ戻しているか。
    @State private var retaking = false
    /// 撮り直しの残り秒数を数えるための「いま」。ThisWeekView と同じ考え方。
    @State private var now = Date()
    /// 横向きの7分割と同じ疑似広角をかける。ここで見えた絵が、横にしたときの枠にそのまま入るように。
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

    private func lens(for slot: Slot) -> RotashLens.Setting {
        RotashLens.setting(for: slot,
                           back: RotashLens.resolve(stored: storedLensWidening),
                           front: frontLens)
    }

    /// ライブビューのレンズ。内カメなら上下を黒くして横を広げ、外カメなら疑似広角。
    private var liveLens: RotashLens.Setting {
        RotashLens.setting(isFront: camera.position == .front,
                           back: RotashLens.resolve(stored: storedLensWidening),
                           front: frontLens)
    }
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
                        strips(in: geometry.size)
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

    // MARK: - 枠

    /// 前日 | 今日（ライブビュー） | 翌日。
    /// 今日の枠は、横向きの7分割の1枠と同じ縦横比にする。ここで見えた範囲が、
    /// 横にしたときの枠にそのまま入る。
    private func strips(in size: CGSize) -> some View {
        GeometryReader { area in
            let aspect = Self.cellAspect(portraitSize: size)
            let height = area.size.height
            let width = min(height * aspect, area.size.width * 0.62)
            let side = max(0, (area.size.width - width) / 2 - 1)

            HStack(spacing: 1) {
                neighbor(day - 1).frame(width: side, height: height)
                todayCell.frame(width: width, height: height)
                neighbor(day + 1).frame(width: side, height: height)
            }
            .frame(width: area.size.width, height: height)
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

    private var todayCell: some View {
        ZStack {
            if showsLive {
                liveContent
            } else if let slot, slot.isFilled {
                PhotoImageView(slot: slot, maxPixel: 720, lens: lens(for: slot))
            } else {
                Palette.surface
            }
        }
        .clipped()
        .overlay(Rectangle().stroke(showsLive ? Palette.live : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { if showsLive { capture() } }
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

    /// 隣の日。前日は写真（あれば）、翌日はまだ空いた枠。
    /// 未来の担当者はここでも出さない。
    @ViewBuilder
    private func neighbor(_ index: Int) -> some View {
        if let week = app.group?.currentWeek, let slot = week.slot(at: index) {
            ZStack {
                if slot.isFilled {
                    PhotoImageView(slot: slot, maxPixel: 480, lens: lens(for: slot))
                        .opacity(0.8)
                } else {
                    Palette.surface
                }
            }
            .clipped()
        } else {
            Palette.background
        }
    }

    // MARK: - 下

    @ViewBuilder
    private var bottomControl: some View {
        VStack(spacing: 10) {
            if showsLive {
                Text(isFilled ? "RETAKE\(retakeCountdown)" : "SHOOT")
                    .rotashLabel(9, color: Palette.live, tracking: 3)
                HStack(spacing: 20) {
                    flipButton
                    shutterButton
                    modeButton
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
        .frame(height: 120)
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

    /// 内カメの方式を、撮りながら切り替えて見くらべるためのボタン（検証用ビルドの内カメだけ）。
    /// 押すたびに次の方式になる。設定画面の「内カメの方式」と同じ値を変える。
    @ViewBuilder
    private var modeButton: some View {
        if RotashFeatureFlags.isTestBuild, camera.position == .front, camera.status == .ready {
            Button {
                storedFrontLensMode = frontLens.mode.next.rawValue
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                VStack(spacing: 3) {
                    Text("MODE").rotashLabel(7, color: Palette.dim, tracking: 1.4)
                    Text(frontLens.mode.label).rotashLabel(10, color: Palette.text, tracking: 0.6)
                }
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

    private var shutterButton: some View {
        Button { capture() } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 64, height: 64)
                Circle()
                    .fill(Color.white)
                    .frame(width: 50, height: 50)
                    .opacity(isCapturing ? 0.35 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
    }

    // MARK: - 撮影

    private func capture() {
        guard !isCapturing, app.canShoot(dayIndex: day) else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let target = day

        camera.capture(fallbackSeed: target) { data in
            Task { @MainActor in
                self.flashOpacity = 0.85
                withAnimation(.easeOut(duration: 0.28)) { self.flashOpacity = 0 }
                if let data {
                    self.app.attachPhoto(data, toDay: target, front: self.camera.position == .front)
                    self.retaking = false
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
