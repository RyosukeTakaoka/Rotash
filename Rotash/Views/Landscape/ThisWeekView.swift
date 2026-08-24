import SwiftUI
import UIKit

/// 横向きのメイン体験。7 分割された状態そのものを見ながら撮る。
struct ThisWeekView: View {

    @EnvironmentObject private var app: AppViewModel
    @StateObject private var camera = CameraController()

    @State private var manualSelection: Int?
    @State private var isCapturing = false
    @State private var flashOpacity: Double = 0

    private var week: RotashWeek? { app.group?.currentWeek }

    /// いま撮影対象になっている枠。
    private var activeDay: Int? {
        guard let week, !week.isComplete else { return nil }
        if let manualSelection, app.canShoot(dayIndex: manualSelection) { return manualSelection }
        return app.suggestedDay
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
            Text(week.isComplete ? "COMPLETE" : "THIS WEEK")
                .rotashLabel(12, color: Palette.text, tracking: 3.4)
            Text(week.title)
                .rotashLabel(10, color: Palette.faint)
            Spacer(minLength: 8)
            Text("\(week.filledCount) / 7")
                .rotashLabel(11, color: week.isComplete ? Palette.text : Palette.dim)
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

    private func grid(week: RotashWeek) -> some View {
        HStack(spacing: 1) {
            ForEach(week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })) { slot in
                cell(slot: slot, week: week)
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
            if let filename = slot.photoFilename {
                PhotoImageView(filename: filename)
            } else if isActive {
                liveContent
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
            CameraPreview(controller: camera)
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

    @ViewBuilder
    private func bottomControl(week: RotashWeek) -> some View {
        if week.isComplete {
            Text("7枚そろいました")
                .rotashLabel(10, color: Palette.text, tracking: 2)
                .padding(.bottom, 14)
        } else if activeDay != nil {
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
            .padding(.bottom, 12)
        } else {
            waitingLine
                .padding(.bottom, 14)
        }
    }

    private var waitingLine: some View {
        let name = app.assignee(forDay: app.todayIndex)?.name.uppercased() ?? "-"
        return Text("TODAY — \(name)")
            .rotashLabel(10, color: Palette.dim, tracking: 2)
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
