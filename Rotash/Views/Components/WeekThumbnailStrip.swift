import SwiftUI

/// Memories 用の小さなプレビュー。
/// 写真がなかった日は暗い枠に「—」を置く（小さい帯では記号は足さない）。
///
/// 既定を薄くしてあるのは、Memories を「リスト」ではなく「積層」に見せるため。
/// 続いていることを数字（連続週数）で出すと、途切れた瞬間に損失回避が働いて
/// そのまま帰ってこなくなる。数字ではなく厚みで見せる。
///
/// `flipped` にすると、左から順に1枚ずつ裏返って裏の7分割になる（週が終わった作品の「裏」）。
/// 裏の写真が無い日（古い写真）は表のまま残る。
struct WeekThumbnailStrip: View {
    let week: RotashWeek
    /// 帯の高さ。nil なら決めず、呼び出し側の形（`.aspectRatio(WorkShape.stripAspect, ...)` など）に合わせて伸びる。
    var height: CGFloat? = 16
    var flipped = false

    var body: some View {
        HStack(spacing: 2) {
            let sorted = week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })
            ForEach(Array(sorted.enumerated()), id: \.element.id) { position, slot in
                Group {
                    if slot.isFilled {
                        FlipCard(flipped: flipped && slot.hasReverse, delay: Double(position) * 0.07) {
                            PhotoImageView(slot: slot, maxPixel: 160)
                        } back: {
                            PhotoImageView(reverseOf: slot, maxPixel: 160)
                        }
                    } else {
                        // 写真がなかった日。横画面の7分割と同じく「—」を置く（ある程度の大きさがあるときだけ）。
                        Rectangle()
                            .fill(Palette.surfaceDeep)
                            .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
                            .overlay {
                                GeometryReader { geometry in
                                    // 「その日には写真がなかった」と決まった日だけ（今日や、まだ来ていない日には出さない）。
                                    if week.state(of: slot) == .noShot, geometry.size.height >= 40 {
                                        Text("—")
                                            .rotashLabel(11, color: Palette.faint, tracking: 0)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
            }
        }
    }
}
