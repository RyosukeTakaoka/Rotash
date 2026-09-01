import SwiftUI

/// Memories 用の小さなプレビュー。
/// 写真がなかった日は空の枠のまま並べる（小さいので記号は足さない）。
///
/// 既定を薄くしてあるのは、Memories を「リスト」ではなく「積層」に見せるため。
/// 続いていることを数字（連続週数）で出すと、途切れた瞬間に損失回避が働いて
/// そのまま帰ってこなくなる。数字ではなく厚みで見せる。
struct WeekThumbnailStrip: View {
    let week: RotashWeek
    var height: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })) { slot in
                Group {
                    if slot.isFilled {
                        PhotoImageView(slot: slot, maxPixel: 160)
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
