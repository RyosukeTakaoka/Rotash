import Foundation

/// アプリの外から Rotash に入ってくる経路。
///
/// 2種類あり、意味がまったく違う。
///
///   rotash://join/ABC123      … 自分のグループの空き枠に呼ぶ（LINE / DM で個別に送る）
///   rotash://new?from=<UUID>  … 公開された作品から来た人が、自分たちのグループを作る
///
/// 分けている理由は測定のためではなく安全のためでもある。
/// 完成作品を Story に載せるとき `join` を貼ってしまうと、
/// 見ず知らずの人が自分たちの7枠に入れてしまう。公開の場に出すのは常に `new` の方。
///
/// そして `new` に載る `from` が、K（作品ひとつから生まれた新しいグループの数）を
/// 測れる唯一の手がかりになる。
enum RotashLink {

    static let scheme = "rotash"

    /// 受け取った URL の意味。
    enum Destination: Equatable {
        /// 既存のグループに参加する。
        case join(code: String)
        /// 作品を見て来た人が、自分たちのグループを作る。
        case create(origin: UUID?)
    }

    // MARK: - 作る

    /// 空き枠に友達を呼ぶリンク。**公開の場には出さないこと。**
    static func joinURL(code: String) -> URL? {
        URL(string: "\(scheme)://join/\(InviteCode.normalize(code))")
    }

    /// 公開された作品に添えるリンク。誰が見てもよい。
    static func createURL(origin: UUID?) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "new"
        if let origin {
            components.queryItems = [URLQueryItem(name: "from", value: origin.uuidString)]
        }
        return components.url
    }

    // MARK: - 読む

    static func destination(for url: URL) -> Destination? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        // rotash://join/ABC123 は host = "join" / path = "/ABC123"、
        // rotash:join/ABC123 のように host が付かない形で来ることもあるので両方見る。
        var segments: [String] = []
        if let host = url.host { segments.append(host) }
        segments.append(contentsOf: url.pathComponents.filter { $0 != "/" && !$0.isEmpty })

        guard let head = segments.first?.lowercased() else { return nil }

        switch head {
        case "join":
            guard let raw = segments.dropFirst().first else { return nil }
            let code = InviteCode.normalize(raw)
            return InviteCode.isValid(code) ? .join(code: code) : nil

        case "new":
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let from = query?.first { $0.name == "from" }?.value
            return .create(origin: from.flatMap(UUID.init(uuidString:)))

        default:
            return nil
        }
    }
}
