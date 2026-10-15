import SwiftUI

/// 縦のホームに出す「今日の1マス」。
///
/// # 縦は「1日」、横は「1週間」
///
/// 縦では今週の7分割を見せない（横にした瞬間に現れるのが Rotash の体験だから）。
/// ただし何も見せないと、横にすれば作品が見られることに気づけない（友達テストで実際に起きた、#27）。
/// そこで縦には**今日の1マスだけ**を大きく置く。7分割の1枠は縦に細長いので、縦に持った画面とよく合う。
/// 左右には、となりの日が少しだけはみ出して見える。「横に続きがある」ことが、言葉なしで分かる。
///
/// # ふた
///
/// 今日の写真には「ふた」がかかっていて（ぼかし）、横にすると開く。
/// 横にすること自体を、見たいものを開ける動きにする（#35）。
/// 何が撮られたかは縦でも分かる（ぼけた色と形）ので、「何を撮った？」で開く理由にもなる。
///
/// 横にするきっかけは、文字ではなく、スマホの形が横に倒れる動きで示す。
/// 「視差効果を減らす」がオンの人には動かさない。
struct TodayCard: View {
    let week: RotashWeek
    let todayIndex: Int
    /// 今日の担当（その日になっているので公開してよい）。
    let assigneeName: String?
    let isMine: Bool

    /// となりの日が見えている幅。
    private let peek: CGFloat = 26
    private let gap: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 押したときに、横にするきっかけを一度だけ大きく揺らす。
    @State private var nudges = 0

    private var today: Slot? { week.slot(at: todayIndex) }

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let cellWidth = min(height * WorkShape.cellAspect,
                                max(geometry.size.width - (peek + gap) * 2, 40))
            HStack(spacing: gap) {
                neighbor(dayIndex: todayIndex - 1)
                    .frame(width: peek, height: height)
                todayCell
                    .frame(width: cellWidth, height: height)
                neighbor(dayIndex: todayIndex + 1)
                    .frame(width: peek, height: height)
            }
            .frame(width: geometry.size.width, height: height)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UISelectionFeedbackGenerator().selectionChanged()
            nudges += 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(Text("スマホを横にすると、今週の作品が見られます"))
    }

    // MARK: - 今日

    private var todayCell: some View {
        ZStack {
            if let today, today.isFilled {
                // ふた。写真はぼかして、何となく色と形だけ分かるようにする。
                PhotoImageView(slot: today, maxPixel: 240)
                    .blur(radius: 22, opaque: true)
                    .overlay(Color.black.opacity(0.35))
            } else {
                Palette.surface
            }

            // 今日を示す線（横画面の今日の枠と同じ）。
            VStack {
                Rectangle().fill(Palette.live).frame(height: 2)
                Spacer()
            }

            VStack(spacing: 6) {
                Text(RotashDay.label(for: todayIndex))
                    .rotashLabel(11, color: Palette.text, tracking: 1.6)
                if let assigneeName {
                    Text(assigneeName.uppercased())
                        .rotashLabel(10, color: isMine ? Palette.live : Palette.text.opacity(0.85), tracking: 0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
                RotateHint(reduceMotion: reduceMotion, nudges: nudges)
                Text(hintText)
                    .rotashLabel(10, color: isMine && !(today?.isFilled ?? false) ? Palette.live : Palette.text,
                                 tracking: 0.8)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .clipped()
        .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
    }

    /// ふたの上の一言。いま横にすると何ができるか。
    private var hintText: String {
        if today?.isFilled ?? false { return String(localized: "横にして開く") }
        if isMine { return String(localized: "今日はあなたの番\n横にして撮る") }
        return String(localized: "横にして見る")
    }

    private var accessibilityText: Text {
        if let assigneeName {
            return Text("今日の担当 \(assigneeName)。\(hintText)")
        }
        return Text(hintText)
    }

    // MARK: - となりの日

    /// となりの日の端。写真があれば、ふたをかけたまま端だけ見せる。週の外（月曜の前・日曜の後）は空ける。
    @ViewBuilder
    private func neighbor(dayIndex: Int) -> some View {
        if let slot = week.slot(at: dayIndex) {
            ZStack {
                if slot.isFilled {
                    PhotoImageView(slot: slot, maxPixel: 120)
                        .blur(radius: 10, opaque: true)
                        .overlay(Color.black.opacity(0.45))
                } else {
                    Palette.surfaceDeep
                }
            }
            .clipped()
            .opacity(0.7)
        } else {
            Color.clear
        }
    }
}

/// 横にするきっかけ。スマホの形が、縦から横へゆっくり倒れては戻る。
private struct RotateHint: View {
    let reduceMotion: Bool
    let nudges: Int

    var body: some View {
        Group {
            if reduceMotion {
                Image(systemName: "iphone.landscape")
            } else {
                Image(systemName: "iphone")
                    .phaseAnimator([0.0, -90.0]) { content, angle in
                        content.rotationEffect(.degrees(angle))
                    } animation: { angle in
                        // 倒れるのはゆっくり、戻るのは少し間を置いてから。ずっと繰り返す。
                        angle == 0 ? .easeInOut(duration: 0.5).delay(1.4) : .easeInOut(duration: 0.8).delay(0.6)
                    }
            }
        }
        // 押したときだけ、ひと回り大きく弾ませて「これを横に」と伝える。
        .phaseAnimator([1.0, 1.35, 1.0], trigger: nudges) { content, scale in
            content.scaleEffect(scale)
        } animation: { _ in
            .spring(duration: 0.25)
        }
        .font(.system(size: 22, weight: .light))
        .foregroundStyle(Palette.text)
        .frame(height: 30)
    }
}
