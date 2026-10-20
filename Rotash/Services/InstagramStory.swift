import UIKit

/// 作品を Instagram のストーリーズへ、そのまま背景として渡す。
///
/// 共有シートに並ぶ Instagram（`com.burbn.instagram.shareextension`）は、並び順を iOS が決めるので
/// 右へ送らないと見えないことがある。そのうえ開くとフィード・ストーリーズ・メッセージを選ばされる。
/// Rotash の作品は 9:16 の1枚なので、行き先はほぼストーリーズに決まっている。ここから1回で開けるようにする。
///
/// 仕組みは Meta が公開している「ストーリーズへのシェア」の手順どおり：
///   1. 画像を `com.instagram.sharedSticker.backgroundImage` としてクリップボードに置く（5分で消える）
///   2. `instagram-stories://share?source_application=<Facebook App ID>` を開く
/// `canOpenURL` で確かめるために、Info.plist の `LSApplicationQueriesSchemes` に `instagram-stories` を入れてある。
@MainActor
enum InstagramStory {

    /// Meta for Developers で作ったアプリの「アプリ ID」（数字だけの文字列）。秘密鍵ではない。
    ///
    /// 2023年1月から、これが無いと Instagram 側で「このアプリはストーリーズへのシェアに対応していません」と出る。
    /// 空のあいだは共有シートに「Instagram ストーリーズ」を出さない（押しても失敗するだけなので）。
    /// そのあいだも、iOS が並べる Instagram そのものからは共有できる。
    static let facebookAppID = ""

    static var isAvailable: Bool {
        guard let url = shareURL else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// 画像を渡して Instagram を開く。開けたかどうかを返す。
    static func share(imageData data: Data, completion: @escaping @MainActor (Bool) -> Void) {
        guard let url = shareURL else { return completion(false) }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": data]],
            options: [.expirationDate: Date().addingTimeInterval(5 * 60)]
        )
        UIApplication.shared.open(url, options: [:]) { opened in completion(opened) }
    }

    private static var shareURL: URL? {
        guard !facebookAppID.isEmpty else { return nil }
        var components = URLComponents(string: "instagram-stories://share")
        components?.queryItems = [URLQueryItem(name: "source_application", value: facebookAppID)]
        return components?.url
    }
}

/// 共有シートの、アプリが並ぶ列に出る「Instagram ストーリーズ」。
final class InstagramStoryActivity: UIActivity {

    static let type = UIActivity.ActivityType("app.rotash.instagram-story")

    private var imageData: Data?

    override class var activityCategory: UIActivity.Category { .share }

    override var activityType: UIActivity.ActivityType? { Self.type }

    override var activityTitle: String? { String(localized: "Instagram ストーリーズ") }

    override var activityImage: UIImage? { Self.icon }

    // 共有シートは、これらをいつもメインスレッドで呼ぶ。
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        MainActor.assumeIsolated { InstagramStory.isAvailable }
            && activityItems.contains { Self.imageData(from: $0) != nil }
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        imageData = activityItems.lazy.compactMap(Self.imageData(from:)).first
    }

    override func perform() {
        guard let imageData else { return activityDidFinish(false) }
        MainActor.assumeIsolated {
            InstagramStory.share(imageData: imageData) { [weak self] opened in
                self?.activityDidFinish(opened)
            }
        }
    }

    /// 作品は書き出した画像ファイルの URL で渡ってくる（`WorkExporter.shareCardURL`）。
    private static func imageData(from item: Any) -> Data? {
        switch item {
        case let url as URL where url.isFileURL:
            return try? Data(contentsOf: url)
        case let image as UIImage:
            return image.jpegData(compressionQuality: 0.94)
        default:
            return nil
        }
    }

    /// Instagram のロゴは使わない（借り物の絵を描かない）。Instagram らしい色と「ストーリーに足す」の印だけ。
    /// 名前は下に「Instagram ストーリーズ」と出るので、これで迷わない。
    private static let icon: UIImage = {
        let size = CGSize(width: 60, height: 60)
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: 14).addClip()
            let colors = [UIColor(red: 0.51, green: 0.23, blue: 0.71, alpha: 1),
                          UIColor(red: 0.88, green: 0.19, blue: 0.42, alpha: 1),
                          UIColor(red: 0.97, green: 0.47, blue: 0.22, alpha: 1)].map(\.cgColor)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors as CFArray,
                                         locations: [0, 0.55, 1]) {
                context.cgContext.drawLinearGradient(gradient,
                                                     start: CGPoint(x: size.width, y: 0),
                                                     end: CGPoint(x: 0, y: size.height),
                                                     options: [])
            }
            let symbol = UIImage(systemName: "plus.circle",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .medium))?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            if let symbol {
                symbol.draw(in: CGRect(x: (size.width - symbol.size.width) / 2,
                                       y: (size.height - symbol.size.height) / 2,
                                       width: symbol.size.width,
                                       height: symbol.size.height))
            }
        }
    }()
}
