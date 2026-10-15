import SwiftUI
import UIKit

/// 写真を全画面で大きく見る。横の7分割の枠と、縦のホームの写真の並び（`PhotoCarousel`）から開く。
/// どちらから開いても同じ見え方・同じ動きにする。
///
/// 写真そのものの形で大きく出し、右下の丸（もう一方のカメラ）を押すか写真を長押しすると、表と裏が入れ替わる。
/// 背景か「×」を押すと閉じる。
struct PhotoViewer: View {
    let slot: Slot
    /// その写真が入っている週（報告するときに送る）。
    let week: RotashWeek
    /// 撮った人の名前（出してよいときだけ）。
    let name: String?
    /// 曜日の横に日付も出すか（今週ではない写真も開く、縦のホームから開いたとき）。
    var showsDate = false
    var onClose: () -> Void

    /// いま大きく出しているのが裏か。丸を押すか写真を長押しすると入れ替わる。
    @State private var showsReverse: Bool

    init(slot: Slot,
         week: RotashWeek,
         name: String?,
         showsDate: Bool = false,
         startsReversed: Bool = false,
         onClose: @escaping () -> Void) {
        self.slot = slot
        self.week = week
        self.name = name
        self.showsDate = showsDate
        self.onClose = onClose
        // 裏返している写真は裏から見せる。
        _showsReverse = State(initialValue: slot.hasReverse && startsReversed)
    }

    var body: some View {
        GeometryReader { geometry in
            let fullWidth = geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
            let fullHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            // 写真（4:3 の横長）が画面に出る高さ。横持ちなら画面の高さいっぱい（上下の端まで）、
            // 縦持ちなら画面の幅に合わせた高さ。丸はその高さの 1/3。
            let photoHeight = min(fullHeight, fullWidth * 3 / 4)
            let diameter = (photoHeight / 3).rounded()
            ZStack {
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture { onClose() }

                // 1つの PhotoImageView のまま中身だけ替える（作り直すと、入れ替えるたびに一瞬暗くなる）。
                // 読む大きさは画面に出る大きさまで（4:3 の横は高さの 4/3）。
                PhotoImageView(filename: showsReverse ? slot.reversePhotoFilename : slot.photoFilename,
                               remoteURL: showsReverse ? slot.reversePhotoURL : slot.photoURL,
                               maxPixel: (photoHeight * 4 / 3).rounded())
                    .natural()
                .overlay(alignment: .bottomTrailing) {
                    if slot.hasReverse {
                        Button { swap() } label: {
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
                    swap()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .vertical)

                VStack {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(RotashDay.label(for: slot.dayIndex))
                            .rotashLabel(11, color: Palette.text, tracking: 1.8)
                        if let name {
                            Text(name.uppercased())
                                .rotashLabel(10, color: Palette.dim, tracking: 0.8)
                                .lineLimit(1)
                        }
                        if showsDate, let date = week.date(of: slot) {
                            Text(RotashDateFormat.monthDay.string(from: date))
                                .rotashLabel(10, color: Palette.faint, tracking: 1)
                        }
                        if let capturedAt = slot.capturedAt {
                            Text(RotashDateFormat.time.string(from: capturedAt))
                                .rotashLabel(10, color: Palette.faint, tracking: 1)
                        }
                        Spacer()
                        PhotoSafetyMenu(slot: slot, week: week) { onClose() }
                        Button { onClose() } label: {
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

    private func swap() {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.2)) { showsReverse.toggle() }
    }
}
