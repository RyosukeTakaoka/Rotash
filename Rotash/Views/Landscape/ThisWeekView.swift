import SwiftUI
import UIKit

/// 横向きのメイン体験。
/// 7分割は誰にでも常に全部見える。撮影だけがその日の担当者に限られる。
struct ThisWeekView: View {

    @EnvironmentObject private var app: AppViewModel
    @StateObject private var camera = CameraController()

    @State private var manualSelection: Int?
    @State private var isCapturing = false
    @State private var flashOpacity: Double = 0

    private var week: RotashWeek? { app.group?.currentWeek }

    /// いま撮影対象になっている枠（= ライブビューが出ている枠）。
    /// タップで選ぶと、撮影済みの枠でも撮り直しとして選択できる。
    private var activeDay: Int? {
        guard let week, !week.isComplete else { return nil }
        if let manualSelection, app.canShoot(dayIndex: manualSelection) { return manualSelection }
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
                    grid(week: week)
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
    }

    // MARK: - Header

    private func header(week: RotashWeek) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("THIS WEEK")
                .rotashLabel(12, color: Palette.text, tracking: 3.4)
            Text(week.title)
                .rotashLabel(10, color: Palette.faint)
            Spacer(minLength: 8)
            if week.isComplete {
                WorkShareButton(week: week) {
                    Text("SHARE").rotashLabel(11, color: Palette.live, tracking: 2.4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - 7 分割
    //
    // 7枚が左から少しずつ埋まっていく状態そのものが Rotash の価値なので、
    // どの枠も常に同じ比率になるよう GeometryReader で幅を明示的に割り当てる
    // （HStack の柔軟なフレームだけに頼ると、内部コンテンツの都合で崩れうるため）。

    private func grid(week: RotashWeek) -> some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 1
            let cellWidth = (geometry.size.width - spacing * 6) / 7
            HStack(spacing: spacing) {
                ForEach(week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })) { slot in
                    cell(slot: slot, week: week)
                        .frame(width: cellWidth)
                }
            }
        }
        .background(Palette.background)
    }

    private func cell(slot: Slot, week: RotashWeek) -> some View {
        let day = slot.dayIndex
        let isActive = activeDay == day
        let shootable = app.canShoot(dayIndex: day)
        let assignee = app.assignee(forDay: day)
        let isToday = day == app.todayIndex && !week.isComplete

        return ZStack {
            if isActive {
                // 撮影中／撮り直し中は自分の写真より優先してライブビューを見せる。
                liveContent
            } else if let filename = slot.photoFilename {
                PhotoImageView(filename: filename)
            } else {
                Palette.surface
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
                capture(day: day)
            } else if shootable {
                manualSelection = day
            }
        }
    }

    @ViewBuilder
    private var liveContent: some View {
        switch camera.status {
        case .ready:
            ZStack(alignment: .topTrailing) {
                CameraPreview(controller: camera)
                Button {
                    camera.switchCamera()
                } label: {
                    Text("FLIP")
                        .rotashLabel(8, color: Palette.text, tracking: 1.2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .disabled(isCapturing)
                .padding(6)
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
        if !week.isComplete, activeDay != nil {
            VStack(spacing: 8) {
                Text(isRetake ? "RETAKE" : "SHOOT")
                    .rotashLabel(9, color: Palette.live, tracking: 3)
                Button { capture(day: activeDay ?? 0) } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: 54, height: 54)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 42, height: 42)
                            .opacity(isCapturing ? 0.35 : 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isCapturing)
            }
            .padding(.bottom, 12)
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
                    self.app.attachPhoto(data, toDay: day)
                    self.manualSelection = nil
                }
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
