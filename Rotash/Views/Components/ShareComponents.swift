import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 作品を共有する。テンプレートも装飾も選択肢も出さない。
///
/// 以前は「7枚をバラで書き出す」「7分割のまま1枚にする」の2択だったが、
/// 前者は元の横長写真をそのまま出すので **Rotash に見えない画像**を配ってしまう。
/// 選ばせる意味が無いどころか害があったので、9:16 の1枚だけにした。
///
/// 完成していなくても押せる。0/7 は招待状、3/7 は「これ何？」、7/7 は作品で、
/// どれも同じ生成器から出る同じ形式の画像でしかない。
///
/// 添えるのは画像と、`rotash://new?from=…` のリンクだけ。
/// **宣伝文は付けない。**「Rotash で作りました！」は広告に見えて、投稿者が恥ずかしい。
/// 画像が十分に強ければ言葉は要らないし、弱いなら言葉では埋まらない。
struct WorkShareButton<Label: View>: View {
    let week: RotashWeek
    @ViewBuilder var label: () -> Label

    @EnvironmentObject private var app: AppViewModel
    @State private var payload: SharePayload?

    var body: some View {
        Button {
            guard let group = app.group else { return }
            var items: [Any] = []
            if let image = WorkExporter.storyCardURL(for: week, in: group) {
                items.append(image)
            }
            // 公開の場に出しても安全なリンク。join と違って、
            // これで自分たちの7枠に他人が入ってくることはない。
            if let link = RotashLink.createURL(origin: group.id) {
                items.append(link)
            }
            guard !items.isEmpty else { return }
            payload = SharePayload(items: items)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .sheet(item: $payload) { payload in
            ActivityView(items: payload.items)
        }
    }
}

/// 空き枠に友達を呼ぶ。
///
/// 送るのは6桁のコードではなく、**いまの作品そのもの**にする。
/// コードだけを LINE に貼っても、受け取った側に見えるのは意味不明な6文字で、
/// 何のアプリかを招待した側が説明しなければならない。
/// 画像を添えれば説明は要らないし、「7枠のうち1つ」であることも見れば分かる。
///
/// こちらは `join` リンクなので、**公開の場には出さないこと**。
/// Story に貼ると見ず知らずの人が自分たちの7枠に入れてしまう。
struct InviteShareButton<Label: View>: View {
    @ViewBuilder var label: () -> Label

    @EnvironmentObject private var app: AppViewModel
    @State private var payload: SharePayload?

    var body: some View {
        Button {
            guard let group = app.group else { return }
            var items: [Any] = ["この1週間、一緒に1枚にしない？"]
            if let image = WorkExporter.storyCardURL(for: group.currentWeek, in: group) {
                items.append(image)
            }
            if let link = RotashLink.joinURL(code: group.inviteCode) {
                items.append(link)
            }
            payload = SharePayload(items: items)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .sheet(item: $payload) { payload in
            ActivityView(items: payload.items)
        }
    }
}
