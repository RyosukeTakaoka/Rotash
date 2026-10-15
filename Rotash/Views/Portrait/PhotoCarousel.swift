import SwiftUI
import UIKit

/// 縦のホームの真ん中に置く、撮られた写真の並び。
///
/// 真ん中は、いちばん新しく撮られた1枚（今日がまだ撮られていなければ、昨日やその前の1枚）。
/// 左には、それより前に撮られた写真が奥へ傾いてのぞいている。
/// 右へすべらせると左の写真が真ん中に来て、真ん中だった写真は右へ下がる。
/// 右に見えるのは真ん中より新しい写真だけなので、はじめ（真ん中がいちばん新しいとき）は何もない。
///
/// 写真には、横の7分割と同じく裏の丸（もう一方のカメラ）を添える。
/// 丸を押すか写真を長押しすると裏返り、写真を押すと全画面で大きく見る（どちらも横の7分割と同じ）。
struct PhotoCarousel: View {

    /// 並べる1枚。報告や日付のために、その写真が入っている週も持つ。
    struct Item: Identifiable {
        let slot: Slot
        let week: RotashWeek
        var id: UUID { slot.id }

        /// 撮った時刻。記録の無い古い写真は、その日の 00:00 とみなす。
        var takenAt: Date {
            slot.capturedAt ?? week.date(of: slot) ?? week.startDate
        }
    }

    /// 新しい順。
    let items: [Item]
    /// 今週（この週の今日の写真には、横の7分割と同じく今日の線を引く）。
    let currentWeekID: UUID
    let todayIndex: Int
    /// 撮った人の名前。
    var name: (Item) -> String?
    /// 写真を押したとき。2つめは、いま裏返しているか（全画面も裏から見せる）。
    var onOpen: (Item, Bool) -> Void

    /// 1枚の「幅 ÷ 高さ」。横画面の1枠（およそ 1 : 3.2）より太くして、写真が見えるようにする（`TodayCard` と同じ）。
    static let aspect: CGFloat = 0.48
    /// 写真の上に重ねる黒の濃さ。真ん中もまぶしすぎないよう少しだけ落とし、横の写真はぐっと暗くする（2026-10-16）。
    private static let centerDim: Double = 0.15
    private static let sideDim: Double = 0.6

    fileprivate static let settle = Animation.spring(response: 0.42, dampingFraction: 0.86)

    /// 真ん中にある写真（0 = いちばん新しい）。
    @State private var index = 0
    /// 裏返している写真。
    @State private var flipped: Set<UUID> = []
    /// 指ですべらせている量。指を離すと、ばねのように戻る。
    @GestureState(resetTransaction: Transaction(animation: PhotoCarousel.settle))
    private var drag = DragState()

    private struct DragState {
        /// 横にすべらせているか（縦なら、引っぱって更新の方に任せる）。動き始めで決める。
        var horizontal: Bool?
        var offset: CGFloat = 0
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = Layout(size: geometry.size)
            ZStack {
                // 真ん中の前後2枚ずつだけ作る（全部の写真を読み込まないように）。
                ForEach(visibleItems, id: \.element.id) { entry in
                    let position = CGFloat(index - entry.offset) + drag.offset / layout.spacing
                    card(entry.element, position: position, isCenter: entry.offset == index)
                        .frame(width: layout.cardSize.width, height: layout.cardSize.height)
                        .modifier(CoverEffect(position: position,
                                              spacing: layout.spacing,
                                              sideSqueeze: layout.sideSqueeze))
                        // 真ん中から2枚ぶん離れると消える。
                        .opacity(Double(min(max(2 - abs(position), 0), 1)))
                        .zIndex(-Double(abs(position)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            // ホームは引っぱって更新できるので、縦の動きは邪魔しない（横に動かしたときだけすべらせる）。
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .updating($drag) { value, state, _ in
                        if state.horizontal == nil {
                            state.horizontal = abs(value.translation.width) > abs(value.translation.height)
                        }
                        guard state.horizontal == true else { return }
                        state.offset = resisted(value.translation.width)
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > abs(value.translation.height) else { return }
                        let predicted = value.predictedEndTranslation.width
                        if dx > 0, predicted > layout.spacing * 0.4 || dx > layout.spacing * 0.3 {
                            move(to: index + 1)
                        } else if dx < 0, predicted < -layout.spacing * 0.4 || dx < -layout.spacing * 0.3 {
                            move(to: index - 1)
                        }
                    }
            )
        }
        // 新しい写真が撮られたら（グループを切り替えたときも）、いちばん新しい1枚に戻る。
        .onChange(of: items.first?.id) { _, _ in index = 0 }
        .onChange(of: items.count) { _, count in index = min(index, max(count - 1, 0)) }
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(to: index - 1)
            case .decrement: move(to: index + 1)
            @unknown default: break
            }
        }
    }

    private var visibleItems: [EnumeratedSequence<[Item]>.Element] {
        Array(items.enumerated()).filter { abs($0.offset - index) <= 2 }
    }

    private func card(_ item: Item, position: CGFloat, isCenter: Bool) -> some View {
        let isFlipped = flipped.contains(item.id)
        let isToday = item.week.id == currentWeekID && item.slot.dayIndex == todayIndex
        return CarouselCard(item: item,
                            name: name(item),
                            isToday: isToday,
                            showsDate: item.week.id != currentWeekID,
                            flipped: isFlipped,
                            isCenter: isCenter) {
            toggleFlip(item)
        }
        // 全体を少し暗くして抑え、横にある写真はさらに暗くして、真ん中を主役にする。
        .overlay(Color.black
            .opacity(Self.centerDim + (Self.sideDim - Self.centerDim) * Double(min(abs(position), 1)))
            .allowsHitTesting(false))
        .contentShape(Rectangle())
        .onTapGesture {
            if isCenter {
                onOpen(item, isFlipped && item.slot.hasReverse)
            } else if let target = items.firstIndex(where: { $0.id == item.id }) {
                // 横の写真を押すと、その写真が真ん中に来る。
                move(to: target)
            }
        }
        // 押してすぐ離すと全画面、少し長く押すと裏返す（横の7分割と同じ）。
        .onLongPressGesture(minimumDuration: 0.25) {
            guard isCenter, item.slot.hasReverse else { return }
            toggleFlip(item)
        }
        .accessibilityAddTraits(isCenter ? .isButton : [])
        .accessibilityHidden(!isCenter)
        .accessibilityAction(named: Text("裏返す")) {
            guard item.slot.hasReverse else { return }
            toggleFlip(item)
        }
    }

    /// 端（いちばん新しい／いちばん古い写真）より先へは、重たく少しだけ動く。
    private func resisted(_ dx: CGFloat) -> CGFloat {
        let atNewest = index == 0 && dx < 0
        let atOldest = index >= items.count - 1 && dx > 0
        return atNewest || atOldest ? dx / 3 : dx
    }

    private func move(to target: Int) {
        let next = min(max(target, 0), max(items.count - 1, 0))
        guard next != index else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(Self.settle) { index = next }
    }

    private func toggleFlip(_ item: Item) {
        UISelectionFeedbackGenerator().selectionChanged()
        if flipped.contains(item.id) { flipped.remove(item.id) } else { flipped.insert(item.id) }
    }

    /// 1枚の大きさと、隣の写真までの距離。
    private struct Layout {
        let cardSize: CGSize
        /// 真ん中の写真の中心から、隣の写真の中心までの距離。
        let spacing: CGFloat
        /// 横にあるときの、横の縮み（1 = そのまま）。
        let sideSqueeze: CGFloat

        /// 隣の写真がのぞく帯の幅（画面の幅に対する割合）。
        ///
        /// 真ん中の写真の大きさとは別に決める。真ん中は大きく見せたいが、隣まで大きいと圧が強いので、
        /// 隣は細い帯がのぞくだけにする（2026-10-16）。
        private static let sideStripRatio: CGFloat = 0.093

        init(size: CGSize) {
            // 縦長の1枚。高さに収まる大きさにしつつ、左右に隣の写真がのぞく幅を残す（画面の幅の 56% まで）。
            let width = max(1, min(size.height * PhotoCarousel.aspect, size.width * 0.56))
            cardSize = CGSize(width: width, height: width / PhotoCarousel.aspect)
            // 隣の写真が、決めた幅の帯になるだけ横に縮める。
            let strip = size.width * Self.sideStripRatio
            sideSqueeze = min(1, strip / (CoverEffect.sideScale * width))
            // 傾いた隣の写真の内側の辺が、真ん中の写真の辺から少し（12pt）離れたところに来るように。
            let gap: CGFloat = 12
            spacing = width / 2 + gap
                + CoverEffect.sideScale * sideSqueeze * width / (2 * (1 - CoverEffect.sideTilt))
        }
    }
}

/// 並びの中の1枚。横の7分割の枠と同じく、上に曜日と名前、下に裏の丸。
private struct CarouselCard: View {
    let item: PhotoCarousel.Item
    let name: String?
    let isToday: Bool
    /// 今週ではない写真は、曜日だけだといつのものか分からないので日付も出す。
    let showsDate: Bool
    let flipped: Bool
    let isCenter: Bool
    var onFlip: () -> Void

    var body: some View {
        let slot = item.slot
        ZStack {
            // 元の写真をそのまま読むとメモリを大きく使うので、1枚の高さに足りる大きさに縮めて読む。
            FlipCard(flipped: flipped && slot.hasReverse, duration: 0.28) {
                PhotoImageView(slot: slot, maxPixel: 720)
            } back: {
                PhotoImageView(reverseOf: slot, maxPixel: 720)
            }

            // 曜日と名前が写真の上でも読めるように、上だけ少し暗くする。
            LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.25), .clear],
                           startPoint: .top,
                           endPoint: UnitPoint(x: 0.5, y: 0.3))
                .allowsHitTesting(false)

            VStack(spacing: 6) {
                Text(RotashDay.label(for: slot.dayIndex))
                    .rotashLabel(11, color: Palette.text, tracking: 1.6)
                if let name {
                    Text(name.uppercased())
                        .rotashLabel(10, color: Palette.text.opacity(0.85), tracking: 0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                if showsDate, let date = item.week.date(of: slot) {
                    Text(RotashDateFormat.monthDay.string(from: date))
                        .rotashLabel(9, color: Palette.text.opacity(0.6), tracking: 1)
                }
                Spacer(minLength: 0)
            }
            .shadow(color: .black.opacity(0.6), radius: 2)
            .padding(.top, 16)
            .padding(.horizontal, 8)
            .allowsHitTesting(false)

            if slot.hasReverse {
                // 大きく出ていない方を丸で添える。裏返すと、丸には表が入る。押すと裏返る（長押しと同じ）。
                GeometryReader { geometry in
                    let diameter = min(geometry.size.width * 0.42, geometry.size.height * 0.22).rounded()
                    Button(action: onFlip) {
                        PhotoImageView(filename: flipped ? slot.photoFilename : slot.reversePhotoFilename,
                                       remoteURL: flipped ? slot.photoURL : slot.reversePhotoURL,
                                       maxPixel: 240)
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    // 横にある写真の丸は押せない（押すと、その写真が真ん中に来る）。
                    .allowsHitTesting(isCenter)
                    .padding(.bottom, 14)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
                }
            }

            // 今日の写真には、横の7分割の今日の枠と同じ線を引く。
            if isToday {
                VStack {
                    Rectangle().fill(Palette.live).frame(height: 2)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
        .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(RotashDay.label(for: slot.dayIndex)) \(name ?? "")"))
        .accessibilityHint(Text("押すと大きく表示します。長押しで裏返します"))
    }
}

/// 横にある写真を、外側の辺が奥へ下がるように傾けて、少し小さく・細く見せる。
///
/// `position` は真ん中からの位置（0 = 真ん中、-1 = 左隣、1 = 右隣）。指の動きに合わせて小数で動き、
/// その途中もなめらかに傾くよう、位置そのものをアニメーションさせる（`animatableData`）。
///
/// 傾きは `rotation3DEffect` ではなく、遠近の変形を直接組み立てて作る。
/// 「どちらの辺が奥へ行くか」を、角度の向きの約束に頼らず、ここで確実に決めるため。
private struct CoverEffect: GeometryEffect {
    /// 横にあるときの、全体の縮み。
    static let sideScale: CGFloat = 0.88
    /// 横にあるときの傾きの強さ。外側の辺は 1 / (1 + これ) 倍、内側の辺は 1 / (1 - これ) 倍の高さになる。
    static let sideTilt: CGFloat = 0.07

    var position: CGFloat
    var spacing: CGFloat
    /// 横にあるときの、横の縮み（1 = そのまま）。細い帯がのぞくくらいにする（`Layout.sideSqueeze`）。
    var sideSqueeze: CGFloat

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let width = size.width
        let height = size.height
        guard width > 0, height > 0 else { return ProjectionTransform() }

        let amount = min(abs(position), 1)
        let direction: CGFloat = position < 0 ? -1 : 1
        let squeeze = 1 - (1 - sideSqueeze) * amount
        let scale = 1 - (1 - Self.sideScale) * amount
        // 遠近の強さ。左の写真（direction = -1）は左の辺が、右の写真は右の辺が奥へ下がる。
        let perspective = direction * Self.sideTilt * amount / (width / 2)
        // 動かした先の中心。
        let centerX = width / 2 + position * spacing
        let centerY = height / 2

        // 中心を原点に (u, v) と置いて、
        //   x' = scale * squeeze * u / (1 + perspective * u) + centerX
        //   y' = scale * v / (1 + perspective * u) + centerY
        // となる変形を、元の座標 (x, y) = (u + width/2, v + height/2) の行列にしたもの。
        let w0 = 1 - perspective * width / 2
        var transform = ProjectionTransform()
        transform.m11 = scale * squeeze + centerX * perspective
        transform.m12 = centerY * perspective
        transform.m13 = perspective
        transform.m21 = 0
        transform.m22 = scale
        transform.m23 = 0
        transform.m31 = -scale * squeeze * width / 2 + centerX * w0
        transform.m32 = -scale * height / 2 + centerY * w0
        transform.m33 = w0
        return transform
    }
}
