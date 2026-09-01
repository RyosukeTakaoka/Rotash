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
    @State private var draftTitle = ""

    private var week: RotashWeek? { app.group?.currentWeek }

    /// いま撮影対象になっている枠（= ライブビューが出ている枠）。
    /// タップで選ぶと、撮影済みの枠でも撮り直しとして選択できる。
    private var activeDay: Int? {
        guard let week, !week.isFinished else { return nil }
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

        } else if app.titlableWeek?.id == week.id {
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
                PhotoImageView(slot: slot)
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

    // 完成したかどうかは7枚の写真そのもの（と SHARE ボタンの有無）で伝わるので、
    // ここでは撮影ボタン以外のテキストは出さない。
    // 今日の担当が誰かも、各枠に既に名前が出ているので改めて言葉にしない。
    @ViewBuilder
    private func bottomControl(week: RotashWeek) -> some View {
        if !week.isFinished, activeDay != nil {
            VStack(spacing: 8) {
                Text(isRetake ? "RETAKE" : "SHOOT")
                    .rotashLabel(9, color: Palette.live, tracking: 3)

                // FLIP は狭い枠の隅だと押しづらいので、シャッターの横に置いて
                // 指の届く大きさ（44pt 以上）にしている。
                // 反対側に同じ幅の余白を入れて、シャッターは中央のままにする。
                HStack(spacing: 20) {
                    flipButton
                    shutterButton
                    Color.clear.frame(width: flipButtonWidth, height: 1)
                }
            }
            .padding(.bottom, 12)
        }
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

    private var shutterButton: some View {
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
