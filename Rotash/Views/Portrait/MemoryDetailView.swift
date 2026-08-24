import SwiftUI

/// 完成した過去作品。縦でもプレビューしてよい。
struct MemoryDetailView: View {

    let week: RotashWeek
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button("← BACK") { dismiss() }
                            .font(Typo.label(10, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(Palette.dim)
                        Spacer()
                        Text(week.isComplete ? "COMPLETE" : "\(week.filledCount) / 7")
                            .rotashLabel(9, color: Palette.faint)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 20)

                    Text(week.title)
                        .font(Typo.title(19))
                        .tracking(1.5)
                        .foregroundStyle(Palette.text)
                        .padding(.bottom, 18)

                    WeekThumbnailStrip(week: week, height: 78)
                        .padding(.bottom, 26)

                    HairLine()

                    VStack(spacing: 2) {
                        ForEach(week.slots.sorted(by: { $0.dayIndex < $1.dayIndex })) { slot in
                            photoRow(slot)
                        }
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 26)

                    WorkShareButton(week: week) {
                        Text("SHARE")
                            .font(Typo.label(13, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Palette.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Palette.text)
                    }

                    Text("加工はしません。7枚の写真そのものを書き出します。")
                        .rotashLabel(9, color: Palette.faint, tracking: 0.4)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func photoRow(_ slot: Slot) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let filename = slot.photoFilename {
                PhotoImageView(filename: filename, maxPixel: 900)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Palette.surfaceDeep)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
            }
            // 終わった週なので担当者はすべて公開してよい。
            HStack(spacing: 8) {
                Text(RotashDay.label(for: slot.dayIndex))
                    .rotashLabel(9, color: Palette.text, tracking: 1.6)
                if let name = assigneeName(for: slot) {
                    Text(name.uppercased())
                        .rotashLabel(9, color: Palette.dim, tracking: 0.8)
                }
            }
            .padding(10)
        }
    }

    private func assigneeName(for slot: Slot) -> String? {
        guard let id = slot.assigneeID ?? slot.takenByMemberID else { return nil }
        return app.group?.member(withID: id)?.name
    }
}
