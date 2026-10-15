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
///
/// # Web のリンク（Universal Links）
///
/// `rotash://` はアプリが入っている人にしか効かない（入っていない人が押しても何も起きない）。
/// そこで招待は `https://rotash-f83a4.web.app/j/ABC123` でも送れるようにしてある。
///   - アプリが入っていれば、そのまま参加画面が開く（apple-app-site-association）
///   - 入っていなければ Web のページが開き、コードのコピーとアプリの入手先が出る（`web/j/index.html`）
///   - アプリを入れたあとは、参加画面の「貼り付け」でコードが入る（`code(fromPasted:)`）
/// Web 側（Firebase Hosting）を公開するまでは `RotashFeatureFlags.usesWebInviteLinks` を false にしておく。
enum RotashLink {

    static let scheme = "rotash"
    /// 招待の Web ページを置いている場所（Firebase Hosting）。
    static let webHost = "rotash-f83a4.web.app"

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
        let normalized = InviteCode.normalize(code)
        if RotashFeatureFlags.usesWebInviteLinks {
            return URL(string: "https://\(webHost)/j/\(normalized)")
        }
        return URL(string: "\(scheme)://join/\(normalized)")
    }

    /// 貼り付けられた文字から招待コードを取り出す。コードそのもの・Web のリンク・`rotash://` のリンクのどれでもよい。
    static func code(fromPasted text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if let url = URL(string: text), case let .join(code)? = destination(for: url) { return code }
        // 文章ごと貼られた（「招待コード ABC123」）ときは、その中のリンクかコードを探す。
        for word in text.split(whereSeparator: { $0.isWhitespace || $0 == "\n" }) {
            let token = String(word)
            if let url = URL(string: token), case let .join(code)? = destination(for: url) { return code }
            let normalized = InviteCode.normalize(token)
            if normalized.count == token.count, InviteCode.isValid(normalized) { return normalized }
        }
        return nil
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
        // Web のリンク（https://rotash-f83a4.web.app/j/ABC123 ・ /new?from=…）。
        if url.scheme?.lowercased() == "https", url.host?.lowercased() == webHost {
            let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            switch parts.first?.lowercased() {
            case "j":
                guard let raw = parts.dropFirst().first else { return nil }
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
