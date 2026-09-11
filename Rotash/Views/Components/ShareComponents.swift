import SwiftUI
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// `rotash://` のリンクを、**文章として送れる相手にだけ**渡す。
///
/// このリンクを共有物にそのまま混ぜると、2つのことが同時に起きる。
///
///   1. AirDrop が共有先の一覧から消える。
///      AirDrop はファイルか画像しか運べず、独自スキームの URL は運べない。
///      運べないものが1つでも混ざると、AirDrop ごと選べなくなる。
///   2. 受け取った側には `rotash://new?from=8C2F…` という文字列がそのまま出る。
///      アプリを持っていない人には押せもしないので、ただの意味不明な文字列になる。
///
/// なので、リンクを渡すのはメッセージやメールのように「文章を送る」相手だけにする。
/// AirDrop や写真アプリには渡さない。渡さなければ、そちらは画像だけを綺麗に受け取れる。
final class ShareableLink: NSObject, UIActivityItemSource {
    private let url: URL

    init(_ url: URL) {
        self.url = url
        super.init()
    }

    // 実物ではなく「文字列を渡すつもりだ」とだけ伝える。
    // ここで URL を返すと、渡さないと決めた相手にも URL として扱われてしまう。
    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { "" }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        switch activityType {
        case .some(.airDrop), .some(.saveToCameraRoll), .some(.assignToContact),
             .some(.print), .some(.addToReadingList):
            return nil
        default:
            return url.absoluteString
        }
    }
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
/// 出すのは **画像1枚だけ**。
/// **宣伝文は付けない。**「Rotash で作りました！」は広告に見えて、投稿者が恥ずかしい。
/// 画像が十分に強ければ言葉は要らないし、弱いなら言葉では埋まらない。
///
/// `rotash://new?from=…` のリンクも添えない。
/// 公開の場に出す画像に付けても、アプリを持っていない人には押せない文字列でしかなく、
/// そのうえ AirDrop を共有先から消してしまう（ShareableLink のコメントを参照）。
/// K を測る手がかりは失われるが、それは Web に置ける本物のリンクができてからでよい。
struct WorkShareButton<Label: View>: View {
    let week: RotashWeek
    @ViewBuilder var label: () -> Label

    @EnvironmentObject private var app: AppViewModel
    @State private var payload: SharePayload?

    var body: some View {
        Button {
            guard let group = app.group,
                  let image = WorkExporter.shareCardURL(for: week, in: group)
            else { return }
            AnalyticsService.workShareTapped(filledCount: week.filledCount, isComplete: week.isComplete)
            payload = SharePayload(items: [image])
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .sheet(item: $payload) { payload in
            ActivityView(items: payload.items) { completed in
                if completed {
                    AnalyticsService.workShareCompleted(isComplete: week.isComplete)
                }
            }
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
            AnalyticsService.inviteShareTapped()
            // 招待コードは文章の中に入れる。リンクが押せない相手（アプリ未導入・
            // 独自スキームを繋がない LINE など）でも、これなら手で入力して入れる。
            var items: [Any] = ["この1週間、一緒に1枚にしない？\n招待コード \(group.inviteCode)"]
            if let image = WorkExporter.shareCardURL(for: group.currentWeek, in: group) {
                items.append(image)
            }
            // リンクは文章を送る相手にだけ。AirDrop で画像だけ渡すこともできるように。
            if let link = RotashLink.joinURL(code: group.inviteCode) {
                items.append(ShareableLink(link))
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
