import SwiftUI

/// 縦は「準備するところ」、横は「Rotash 体験そのもの」。
struct RootView: View {

    @EnvironmentObject private var app: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

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
        .background(Palette.background)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { app.rollWeekIfNeeded() }
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
