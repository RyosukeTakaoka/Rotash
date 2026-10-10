import SwiftUI

/// Memories 用の小さなプレビュー。
/// 写真がなかった日は空の枠のまま並べる（小さいので記号は足さない）。
///
/// 既定を薄くしてあるのは、Memories を「リスト」ではなく「積層」に見せるため。
/// 続いていることを数字（連続週数）で出すと、途切れた瞬間に損失回避が働いて
/// そのまま帰ってこなくなる。数字ではなく厚みで見せる。
///
/// `flipped` にすると、左から順に1枚ずつ裏返って裏の7分割になる（週が終わった作品の「裏」）。
/// 裏の写真が無い日（古い写真・パノラマ）は表のまま残る。
struct WeekThumbnailStrip: View {
    let week: RotashWeek
    var height: CGFloat = 16
    var flipped = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })) { slot in
                Group {
                    if slot.isFilled {
                        FlipCard(flipped: flipped && slot.hasReverse) {
                            PhotoImageView(slot: slot, maxPixel: 160)
                        } back: {
                            PhotoImageView(reverseOf: slot, maxPixel: 160)
                        }
                        .animation(.easeInOut(duration: 0.45).delay(Double(slot.dayIndex) * 0.07), value: flipped)
                    } else {
                        Rectangle()
                            .fill(Palette.surfaceDeep)
                            .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
            }
        }
    }
}
