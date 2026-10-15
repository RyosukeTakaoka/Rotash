import SwiftUI

/// 縦のホームに出す「今日の1マス」。
///
/// グループにまだ1枚も写真が無いときだけ出す。1枚でも撮られたら、代わりに撮られた写真の並び（`PhotoCarousel`）を出す。
///
/// # 縦は「1日」、横は「1週間」
///
/// 縦では今週の7分割を見せない（横にした瞬間に現れるのが Rotash の体験だから）。
/// 縦に出すのは今日の1枚だけで、縦に持った画面に合う縦長の形で大きく置く。
/// 横画面の1枠よりは太い（細長いままだと写真がほとんど見えず、左右が空きすぎるので。2026-10-15）。
///
/// 今日の写真は、ぼかさずそのまま見せる。「◯◯が撮った」の通知から開いた人に、その1枚がすぐ見えるように。
/// 横にすると見えるのは、1週間の全体。
///
/// 「横にして見る」のような案内は出さない（うるさいだけなので。横にすることは、
/// 初めて入った直後に横の作品画面を見せて覚えてもらう。`RootView`）。
/// 出すのは、自分の番でまだ撮っていない日の「今日はあなたの番 / 横にして撮る」だけ。
struct TodayCard: View {
    let week: RotashWeek
    /// この端末で見えなくしている写真か（ブロック・報告）。見えなくした写真は出さない。
    var hides: (Slot) -> Bool = { _ in false }
    let todayIndex: Int
    /// 今日の担当（その日になっているので公開してよい）。
    let assigneeName: String?
    let isMine: Bool

    init(week: RotashWeek,
         hides: @escaping (Slot) -> Bool = { _ in false },
         todayIndex: Int,
         assigneeName: String?,
         isMine: Bool) {
        self.week = week
        self.hides = hides
        self.todayIndex = todayIndex
        self.assigneeName = assigneeName
        self.isMine = isMine
    }

    /// 高さに対する幅。横画面の1枠（およそ 1 : 3.2）より太くして、写真が見えるようにする。
    static let aspect: CGFloat = PhotoCarousel.aspect

    private var today: Slot? { week.slot(at: todayIndex) }
    private var isMyTurnToShoot: Bool { isMine && !(today?.isFilled ?? false) }

    var body: some View {
        ZStack {
            if let today, today.isFilled, hides(today) {
                HiddenPhotoPlaceholder()
            } else if let today, today.isFilled {
                PhotoImageView(slot: today, maxPixel: 720)
                    // 上の曜日・名前と下の一言が、写真の上でも読めるように、上下だけ少し暗くする。
                    .overlay(
                        LinearGradient(stops: [.init(color: .black.opacity(0.5), location: 0),
                                               .init(color: .clear, location: 0.2),
                                               .init(color: .clear, location: 0.75),
                                               .init(color: .black.opacity(0.45), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    )
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
                if isMyTurnToShoot {
                    Text("今日はあなたの番\n横にして撮る")
                        .rotashLabel(10, color: Palette.live, tracking: 0.8)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .clipped()
        .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(Text("スマホを横にすると、今週の作品が見られます"))
    }

    private var accessibilityText: Text {
        let name = assigneeName ?? ""
        if isMyTurnToShoot {
            return Text("今日はあなたの番です")
        }
        return Text("今日の担当 \(name)")
    }
}
