import SwiftUI

/// Memories 用の小さな 7 枚プレビュー。
struct WeekThumbnailStrip: View {
    let week: RotashWeek
    var height: CGFloat = 46

    var body: some View {
        HStack(spacing: 2) {
            ForEach(week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })) { slot in
                Group {
                    if let filename = slot.photoFilename {
                        PhotoImageView(filename: filename, maxPixel: 160)
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
