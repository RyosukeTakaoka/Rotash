import SwiftUI

/// 写真の「…」。報告する・この人の写真を見えなくする（App Store ガイドライン 1.2）。
///
/// 友達どうしの閉じたグループでも、困った写真を止める手段は要る。
/// どちらもこの端末ですぐに見えなくなる。報告は運営に届き、見えなくするのは自分の端末だけ。
/// 自分が撮った写真には出さない。
struct PhotoSafetyMenu: View {
    let slot: Slot
    let week: RotashWeek
    /// 選んだあとに、開いている全画面などを閉じる。
    var onDone: () -> Void

    init(slot: Slot, week: RotashWeek, onDone: @escaping () -> Void = {}) {
        self.slot = slot
        self.week = week
        self.onDone = onDone
    }

    @EnvironmentObject private var app: AppViewModel
    @State private var confirmReport = false
    @State private var confirmHide = false

    private var takerName: String? {
        slot.takenByMemberID.flatMap { app.group?.member(withID: $0)?.name }
    }

    var body: some View {
        if let taker = slot.takenByMemberID, taker != app.group?.myMemberID {
            Menu {
                Button(role: .destructive) { confirmReport = true } label: {
                    Label("この写真を報告する", systemImage: "exclamationmark.bubble")
                }
                Button { confirmHide = true } label: {
                    Label("この人の写真を見えなくする", systemImage: "eye.slash")
                }
            } label: {
                Text("…")
                    .rotashLabel(18, color: Palette.text, tracking: 0)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .contentShape(Rectangle())
            }
            .confirmationDialog("この写真を報告しますか？", isPresented: $confirmReport, titleVisibility: .visible) {
                Button("報告する", role: .destructive) {
                    app.report(slot, in: week)
                    onDone()
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("運営が確認して対応します。この写真は、この端末ではすぐに表示されなくなります。")
            }
            .confirmationDialog("この人の写真を見えなくしますか？", isPresented: $confirmHide, titleVisibility: .visible) {
                Button("見えなくする", role: .destructive) {
                    app.setMemberHidden(taker, hidden: true)
                    onDone()
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("\(takerName ?? String(localized: "この人")) の写真が、この端末では表示されなくなります。相手には伝わりません。ホームのメンバーを長く押すと元に戻せます。")
            }
        }
    }
}

/// この端末で見えなくしている写真の代わりに置くもの。
struct HiddenPhotoPlaceholder: View {
    var body: some View {
        ZStack {
            Palette.surfaceDeep
            Image(systemName: "eye.slash")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Palette.faint)
        }
    }
}
