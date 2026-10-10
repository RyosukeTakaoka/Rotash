import SwiftUI

/// 完成した過去作品。縦でもプレビューしてよい。
///
/// # 画面の組み立て
///
/// 上に作品全体（7分割）、その下に1日ずつ大きく見る場所を置く。
/// - 7分割の枠を押すと、その日が下に大きく出る。下を左右にめくると、上の選んでいる枠も動く。
/// - 下の大きい写真は、右下の丸（もう一方のカメラ）を押すと大小が入れ替わる。
/// - 「裏返す」で作品全体が左から1枚ずつ裏返る（下の写真も裏が大きくなる）。
///
/// 以前は7枚を縦に長く並べていたが、作品の形（横に7つ並ぶ）が見えず、
/// どこを見ているか分からなくなりやすかったので、作品全体と1日を同時に見せる形にした。
struct MemoryDetailView: View {

    let week: RotashWeek
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss
    /// 作品を裏返しているか。終わった週なので、表も裏もいつでも見られる。
    @State private var flipped = false
    /// 下に大きく出している日。
    @State private var selectedDay: Int?
    /// 丸を押して、大きい写真と丸を入れ替えている日。
    @State private var swappedDays: Set<Int> = []

    private var slots: [Slot] { week.slots.sorted { $0.dayIndex < $1.dayIndex } }

    /// 下に大きく出す日。はじめは写真のある最初の日。
    private var currentDay: Int {
        selectedDay ?? slots.first(where: \.isFilled)?.dayIndex ?? slots.first?.dayIndex ?? 0
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    titleBlock
                    work
                        .padding(.bottom, 12)
                    flipButton
                        .padding(.bottom, 18)
                    HairLine()
                    dayViewer
                        .padding(.top, 18)
                        .padding(.bottom, 20)
                    HairLine()
                        .padding(.bottom, 22)
                    shareButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 上

    private var topBar: some View {
        HStack {
            Button("← BACK") { dismiss() }
                .font(Typo.label(10, weight: .medium))
                .tracking(2)
                .foregroundStyle(Palette.dim)
            Spacer()
            Text("\(week.filledCount) / \(week.slots.count)")
                .rotashLabel(9, color: Palette.faint)
        }
        .padding(.top, 22)
        .padding(.bottom, 20)
    }

    /// その週に名前が付いていれば、日付より先に読ませる。
    /// 曜日も日付も担当者名もシステムが出したものなので、ここだけが人の言葉になる。
    @ViewBuilder
    private var titleBlock: some View {
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
    }

    // MARK: - 作品全体（7分割）

    /// 横画面と同じく、7つの枠を横に並べる。押した日が下に大きく出る。
    private var work: some View {
        HStack(spacing: 2) {
            ForEach(slots) { slot in
                VStack(spacing: 6) {
                    // 横画面で見る作品と同じ形の枠にする。
                    Color.clear
                        .aspectRatio(WorkShape.cellAspect, contentMode: .fit)
                        .overlay { workCell(slot) }
                        .clipped()
                        .overlay(Rectangle().stroke(slot.dayIndex == currentDay ? Palette.live : Color.clear,
                                                    lineWidth: 1.5))
                    Text(RotashDay.label(for: slot.dayIndex))
                        .rotashLabel(8,
                                     color: slot.dayIndex == currentDay ? Palette.live : Palette.faint,
                                     tracking: 0.8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) { selectedDay = slot.dayIndex }
                }
            }
        }
    }

    @ViewBuilder
    private func workCell(_ slot: Slot) -> some View {
        if slot.isFilled {
            FlipCard(flipped: flipped && slot.hasReverse) {
                PhotoImageView(slot: slot, maxPixel: 300)
            } back: {
                PhotoImageView(reverseOf: slot, maxPixel: 300)
            }
            // 左から1枚ずつ裏返る。
            .animation(.easeInOut(duration: 0.45).delay(Double(slot.dayIndex) * 0.07), value: flipped)
        } else {
            // 写真がなかった日。作品の一部としてそのまま残す。
            Rectangle()
                .fill(Palette.surfaceDeep)
                .overlay(Text("—").rotashLabel(11, color: Palette.faint, tracking: 0))
        }
    }

    @ViewBuilder
    private var flipButton: some View {
        if week.slots.contains(where: { $0.hasReverse }) {
            Button {
                flipped.toggle()
                swappedDays = []
            } label: {
                Text(flipped ? "↺ 表に戻す" : "↻ 裏返す")
                    .rotashLabel(10, color: Palette.text, tracking: 1.6)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 1日ずつ見る

    /// 選んだ日を大きく出す。左右にめくると、となりの日へ移る。
    private var dayViewer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TabView(selection: Binding(get: { currentDay }, set: { selectedDay = $0 })) {
                ForEach(slots) { slot in
                    dayPage(slot)
                        .tag(slot.dayIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // ふだんの写真（横持ちで撮る）は横長の 4:3 なので、その形に合わせる。縦で撮った写真は左右に余白が出る。
            .aspectRatio(4.0 / 3.0, contentMode: .fit)

            if let slot = week.slot(at: currentDay) {
                dayCaption(slot)
            }
        }
    }

    @ViewBuilder
    private func dayPage(_ slot: Slot) -> some View {
        if slot.isFilled {
            // 裏返しているときは裏を大きく出す。丸を押した日は、さらに入れ替える。
            let showsReverse = slot.hasReverse && (flipped != swappedDays.contains(slot.dayIndex))
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Palette.surfaceDeep
                    // 写真そのものの形で出す（切らずに全体を見せる）。
                    if showsReverse {
                        PhotoImageView(reverseOf: slot, maxPixel: 1080).natural()
                    } else {
                        PhotoImageView(slot: slot, maxPixel: 1080).natural()
                    }
                }
                if slot.hasReverse {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if swappedDays.contains(slot.dayIndex) {
                                swappedDays.remove(slot.dayIndex)
                            } else {
                                swappedDays.insert(slot.dayIndex)
                            }
                        }
                    } label: {
                        Group {
                            if showsReverse {
                                PhotoImageView(slot: slot, maxPixel: 300)
                            } else {
                                PhotoImageView(reverseOf: slot, maxPixel: 300)
                            }
                        }
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                }
            }
        } else {
            ZStack {
                Palette.surfaceDeep
                VStack(spacing: 8) {
                    Text("—").rotashLabel(15, color: Palette.faint, tracking: 0)
                    Text("この日は写真がありません")
                        .rotashLabel(9, color: Palette.faint, tracking: 0.6)
                }
            }
            .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
        }
    }

    /// 大きい写真の下の一行。「水 10.08 · RYOSUKE · 19:42」のように、曜日と日付・担当者・撮った時刻。
    /// 終わった週なので担当者はすべて公開してよい。
    private func dayCaption(_ slot: Slot) -> some View {
        Text(captionText(slot))
            .rotashLabel(11, color: Palette.dim, tracking: 1.2)
            .frame(maxWidth: .infinity)
    }

    private func captionText(_ slot: Slot) -> String {
        var parts: [String] = []
        if let date = Calendar.rotash.date(byAdding: .day, value: slot.dayIndex, to: week.startDate) {
            parts.append("\(Self.weekday.string(from: date)) \(Self.monthDay.string(from: date))")
        }
        if let name = assigneeName(for: slot) { parts.append(name.uppercased()) }
        if let capturedAt = slot.capturedAt { parts.append(RotashDateFormat.time.string(from: capturedAt)) }
        return parts.joined(separator: " · ")
    }

    private static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

    /// 曜日の短い表記。端末の言語に合わせる（「水」「Wed」「수」）。
    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    // MARK: - 共有

    private var shareButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            WorkShareButton(week: week) {
                Text("SHARE")
                    .font(Typo.label(13, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Palette.live)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .overlay(Rectangle().stroke(Palette.live, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            Text("加工はしません。画面のまま1枚にして書き出します。")
                .rotashLabel(9, color: Palette.faint, tracking: 0.4)
        }
    }

    private func assigneeName(for slot: Slot) -> String? {
        guard let id = slot.assigneeID ?? slot.takenByMemberID else { return nil }
        return app.group?.member(withID: id)?.name
    }
}
