import Foundation

/// App Store の Rotash のページ。招待の文章に添えて、アプリが入っていない人がそのまま入れられるようにする。
///
/// 自前の招待ページは持たない（置いておく負担が重い）。そのかわり App Store のページを使う。
/// 公開されるまではページが無いので、何も添えない。公開されると、アプリを開いたときに
/// Apple の検索（iTunes Search API。無料・登録不要）で自動的に見つかり、次の招待から添えられる。
/// 公開したときに URL を書き換えて、アプリを出し直す必要はない。
enum AppStoreLink {

    private static let cacheKey = "rotash.appStoreURL"

    /// 見つかっている App Store のページ。まだ公開されていなければ nil。
    static var url: URL? {
        UserDefaults.standard.string(forKey: cacheKey).flatMap(URL.init(string:))
    }

    /// App Store に出ているかを確かめて、見つかれば覚える。起動のたびに裏で呼ぶ（見つかったあとは何もしない）。
    static func refreshIfNeeded() async {
        guard url == nil, let bundleID = Bundle.main.bundleIdentifier else { return }
        // 国ごとに出すかどうかが違うので、端末の国 → 日本 の順に探す。
        var regions: [String] = []
        for region in [Locale.current.region?.identifier.lowercased(), "jp"].compactMap({ $0 })
        where !regions.contains(region) {
            regions.append(region)
        }
        for region in regions {
            if let found = await lookup(bundleID: bundleID, region: region) {
                UserDefaults.standard.set(found.absoluteString, forKey: cacheKey)
                return
            }
        }
    }

    private struct Response: Decodable {
        struct Item: Decodable { let trackViewUrl: String }
        let results: [Item]
    }

    private static func lookup(bundleID: String, region: String) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "bundleId", value: bundleID),
                                  URLQueryItem(name: "country", value: region)]
        guard let requestURL = components?.url,
              let (data, _) = try? await URLSession.shared.data(from: requestURL),
              let response = try? JSONDecoder().decode(Response.self, from: data),
              let first = response.results.first,
              var found = URLComponents(string: first.trackViewUrl)
        else { return nil }
        found.query = nil   // 末尾の計測用の文字（?uo=4）は落とす
        return found.url
    }
}
