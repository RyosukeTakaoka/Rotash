import FirebaseCore
import SwiftUI

@main
struct RotashApp: App {

    @StateObject private var app = AppViewModel()
    /// 押し出し通知のデバイストークンを受け取るため（`AppDelegate`）。
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                // rotash://join/ABC123・rotash://new?from=… の入口。
                // バトンのファイルは RootView の方で受ける。
                .onOpenURL { url in
                    guard !url.isFileURL else { return }
                    app.handle(url)
                }
                // App Store に公開されたら、招待の文章に App Store のリンクを添えるため（`AppStoreLink`）。
                .task { await AppStoreLink.refreshIfNeeded() }
        }
    }
}
