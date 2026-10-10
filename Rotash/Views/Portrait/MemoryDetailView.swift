import SwiftUI

/// 完成した過去作品。縦でもプレビューしてよい。
struct MemoryDetailView: View {

    let week: RotashWeek
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    /// 作品を裏返しているか。終わった週なので、表も裏もいつでも見られる。
    @State private var flipped = false

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
                        Text("\(week.filledCount) 枚")
                            .rotashLabel(9, color: Palette.faint)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 20)

                    // その週に名前が付いていれば、日付より先に読ませる。
                    // 曜日も日付も担当者名もシステムが出したものなので、
                    // ここだけが人の言葉になる。
                    if let title = week.title, !title.isEmpty {
                        Text(title)
                            .font(Typo.title(21))
                            .tracking(0.5)
                            .foregroundStyle(Palette.text)
                            .padding(.bottom, 6)
                        Text(week.dateRange)
                            .rotashLabel(10, color: Palette.faint, tracking: 1.2)
                            .padding(.bottom, 18)
                    } else {
                        Text(week.dateRange)
                            .font(Typo.title(19))
                            .tracking(1.5)
                            .foregroundStyle(Palette.text)
                            .padding(.bottom, 18)
                    }

                    WeekThumbnailStrip(week: week, height: 78, flipped: flipped)
                        .contentShape(Rectangle())
                        .onTapGesture { flipped.toggle() }
                        .padding(.bottom, 10)

                    if week.slots.contains(where: { $0.hasReverse }) {
                        Button { flipped.toggle() } label: {
                            Text(flipped ? "↺ 表に戻す" : "↻ 裏返す")
                                .rotashLabel(10, color: Palette.text, tracking: 1.6)
                                .frame(minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 16)
                    } else {
                        Color.clear.frame(height: 16)
                    }

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

                    Text("加工はしません。画面のまま1枚にして書き出します。")
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
            if slot.isFilled {
                // 裏返しているときは裏を大きく、もう一方を右下の丸に出す。
                let large = flipped && slot.hasReverse
                Group {
                    if large {
                        PhotoImageView(reverseOf: slot, maxPixel: 900)
                    } else {
                        PhotoImageView(slot: slot, maxPixel: 900)
                    }
                }
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay(alignment: .bottomTrailing) {
                    if slot.hasReverse {
                        Group {
                            if large {
                                PhotoImageView(slot: slot, maxPixel: 240)
                            } else {
                                PhotoImageView(reverseOf: slot, maxPixel: 240)
                            }
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .padding(10)
                    }
                }
            } else {
                // 写真がなかった日。作品の一部としてそのまま残す。
                Rectangle()
                    .fill(Palette.surfaceDeep)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
                    .overlay(Text("—").rotashLabel(13, color: Palette.faint, tracking: 0))
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
