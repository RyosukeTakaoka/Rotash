import SwiftUI

@main
struct RotashApp: App {

    @StateObject private var app = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                // rotash://join/ABC123 と rotash://new?from=… の入口。
                .onOpenURL { app.handle($0) }
        }
    }
}
