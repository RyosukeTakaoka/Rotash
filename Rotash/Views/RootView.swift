import Combine
import SwiftUI

/// 縦は「準備するところ」、横は「Rotash 体験そのもの」。
///
/// 例外は、初めてグループを作った・入った直後（`AppViewModel.showsWorkInPortrait`）。
struct RootView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            // シートを開いている間は縦向きのまま扱う。
            // 入力中に向きの判定が揺れて、画面ごと作り直されるのを防ぐ。
            let isLandscape = app.activeSheet == nil
                && geometry.size.width > geometry.size.height

            ZStack {
                Palette.background.ignoresSafeArea()

                if isLandscape {
                    if app.hasGroup {
                        ThisWeekView()
                    } else {
                        LandscapeEmptyView()
                    }
                } else if app.showsWorkInPortrait {
                    // 初めて入った直後は、縦に持っていても横の作品画面を見せる（横にすれば、そのまま正しい向きになる）。
                    WorkInPortrait(size: geometry.size)
                } else {
                    PortraitHomeView()
                }
            }
            .statusBarHidden(isLandscape)
            .persistentSystemOverlays(isLandscape ? .hidden : .automatic)
        }
        // キーボードのぶんだけ高さが縮むと、背の高いキーボード（Simeji など）では
        // width > height が一瞬成立して「横向き」と誤判定されてしまう。
        // すると縦向きの画面ごと作り直され、入力中のシートが閉じて開き直す。
        // 向きの判定に使う大きさはキーボードの影響を受けないようにしておく。
        .ignoresSafeArea(.keyboard)
        .background(Palette.background)
        // 起動直後は scenePhase が既に .active なので onChange は発火しない。
        // ここで最初の一回を必ず走らせる（これが無いと、開いただけでは同期されない）。
        .task {
            app.rollWeekIfNeeded()
            app.logAppOpened()
            await app.sync()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                app.rollWeekIfNeeded()
                app.logAppOpened()
                // 戻ってきたときに他の人の写真を取りに行く（リアルタイム購読は使わない）。
                Task { await app.sync() }
            }
        }
        // 開いたまま日付をまたいだとき。
        //
        // .task は起動の一度きり、scenePhase は行き来したときしか動かないので、
        // 画面を開いたまま 0 時を越えると、どちらも動かないまま日だけが変わる。
        // 日曜の夜に開きっぱなしだと月曜になっても週が切り替わらず、
        // しかも「今日が何日目か」は 6（日曜）に丸められるため、
        // アプリは月曜を日曜だと思い込んだまま動き続ける。
        .onReceive(NotificationCenter.default
            .publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)) { _ in
            app.rollWeekIfNeeded()
            Task { await app.sync() }
        }
        // バトン（ファイル）を受け取ったとき。招待などのリンクは RotashApp の方で受ける。
        .onOpenURL { url in
            guard url.isFileURL else { return }
            do {
                try app.importBaton(from: url)
            } catch {
                app.alertMessage = error.localizedDescription
            }
        }
        .alert(app.alertMessage ?? "",
               isPresented: Binding(get: { app.alertMessage != nil },
                                    set: { if !$0 { app.alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}

/// 初めてグループに入った直後の縦画面。横の作品画面（THIS WEEK）を、そのまま横に倒して見せる。
///
/// 「横にして見て」と文字で言わなくても、横向きの画面が出ていれば人は自然とスマホを傾ける。
/// 傾けると本物の横画面に替わり、そのあと縦に戻せばいつもの縦のホームになる。
/// 多くの人はスマホを左に倒して（反時計回りに）横にするので、その向きで正しく読めるように倒しておく。
/// これは見せるだけ。押しても何も起きない（撮るのは、横にしてから）。
private struct WorkInPortrait: View {
    let size: CGSize

    var body: some View {
        ThisWeekView()
            .environment(\.isWorkPreview, true)
            .frame(width: size.height, height: size.width)
            .rotationEffect(.degrees(90))
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("スマホを横にすると、今週の作品が見られます"))
    }
}
