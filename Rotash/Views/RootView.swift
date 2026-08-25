import SwiftUI

/// 縦は「準備するところ」、横は「Rotash 体験そのもの」。
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
            await app.sync()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                app.rollWeekIfNeeded()
                // 戻ってきたときに他の人の写真を取りに行く（リアルタイム購読は使わない）。
                Task { await app.sync() }
            }
        }
        .onOpenURL { url in
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
