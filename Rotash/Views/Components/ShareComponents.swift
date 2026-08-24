import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 完成した作品を共有する。テンプレートも装飾もつけない。
/// ・7 枚の写真そのもの（Instagram のカルーセル用）
/// ・7 分割のまま 1 枚にしたコンタクトシート
struct WorkShareButton<Label: View>: View {
    let week: RotashWeek
    @ViewBuilder var label: () -> Label

    @State private var showOptions = false
    @State private var payload: SharePayload?

    var body: some View {
        Button { showOptions = true } label: { label() }
            .buttonStyle(.plain)
            .confirmationDialog("SHARE", isPresented: $showOptions, titleVisibility: .hidden) {
                Button("7枚の写真を書き出す") {
                    payload = SharePayload(urls: WorkExporter.photoURLs(for: week))
                }
                Button("7分割のまま1枚にする") {
                    if let url = WorkExporter.contactSheetURL(for: week) {
                        payload = SharePayload(urls: [url])
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(item: $payload) { payload in
                ActivityView(items: payload.urls)
            }
    }
}
