import FirebaseAnalytics
import Foundation

/// Firebase Analyticsへの薄いラッパー。
///
/// `GROWTH_DIAGNOSIS.md` K-3の補助指標（3人到達率・完成率・R・K）を実測するために
/// 最小限のイベントだけを送る。イベント名・パラメータ名を増やすときは、
/// まずそれがK-3のどの指標に効くかを先に確認すること。
enum AnalyticsService {

    /// グループを作った。`fromOriginGroup`は、公開された作品を見て
    /// 新しいグループを作った（`rotash://new?from=…`経由）場合にtrue。
    /// これがKの計測に直結する。
    static func groupCreated(fromOriginGroup: Bool) {
        log("group_created", params: ["from_origin_group": fromOriginGroup])
    }

    /// 招待コードで参加した。`viaLink` は招待リンクから来たか（手で入力・貼り付けではなく）。
    static func groupJoined(viaLink: Bool) {
        log("group_joined", params: ["via_link": viaLink])
    }

    /// メンバーが追加された（途中参加）。`memberCount`は追加後の人数で、
    /// 3人到達率の集計に使う。
    static func memberAdded(memberCount: Int) {
        log("member_added", params: ["member_count": memberCount])
    }

    /// 担当日に撮影した。
    static func photoCaptured(filledCount: Int) {
        log("photo_captured", params: ["filled_count": filledCount])
    }

    /// 撮った直後の撮り直し。`secondsAfterFirst` は最初の1枚から何秒後か。
    /// 「事故を救う」ために使われているのか、「撮り比べ」に使われているのかを見る。
    static func photoRetaken(secondsAfterFirst: Int) {
        log("photo_retaken", params: ["seconds_after_first": secondsAfterFirst])
    }

    /// 週が完成した（7/7）。完成率・Rの分子になる。
    static func weekCompleted(memberCount: Int, isFirstWeek: Bool) {
        log("week_completed", params: [
            "member_count": memberCount,
            "is_first_week": isFirstWeek,
        ])
    }

    /// 招待の共有シートを開いた。
    static func inviteShareTapped() {
        log("invite_share_tapped", params: [:])
    }

    /// 作品の共有シートを開いた。`isComplete`は7/7かどうか
    /// （0/7=招待状、3/7=途中経過、7/7=完成作品のどれで押されたか）。
    static func workShareTapped(filledCount: Int, isComplete: Bool) {
        log("work_share_tapped", params: [
            "filled_count": filledCount,
            "is_complete": isComplete,
        ])
    }

    /// 共有シートで実際に送信まで完了した（キャンセルではない）。Kの実測値に最も近い。
    ///
    /// `destination` は送り先の種類（`com.burbn.instagram.shareextension` なら Instagram、
    /// `jp.naver.line.Share` なら LINE など）。「ストーリーなどにあげる割合」を見るのに使う。
    /// Instagram の中でストーリーかフィードかまでは分からない。
    static func workShareCompleted(isComplete: Bool, destination: String?) {
        var params: [String: Any] = ["is_complete": isComplete]
        // Analytics のパラメータの値は100文字まで。
        if let destination { params["destination"] = String(destination.prefix(100)) }
        log("work_share_completed", params: params)
    }

    /// アプリを開いた（前面に来た）。今日、自分が担当か・今日の写真がもう撮られているか。
    ///
    /// PRODUCT_PHILOSOPHY 29-1「自分の担当日以外にもアプリを開くか」を直接測るためのもの。
    /// `is_my_day` が false の開き方が多ければ、撮らない日にも見に来ている。
    static func appOpened(isMyDay: Bool, todayFilled: Bool, groupCount: Int) {
        log("rotash_open", params: [
            "is_my_day": isMyDay,
            "today_filled": todayFilled,
            "group_count": groupCount,
        ])
    }

    /// 横にして今週の作品を見た（横画面が出るたび）。
    static func weekViewed(isMyDay: Bool, todayFilled: Bool) {
        log("week_viewed", params: ["is_my_day": isMyDay, "today_filled": todayFilled])
    }

    /// そのグループで初めて横にした。招待で入った人は、入ってから何分後か（作った人は -1）。
    /// 「横にすると見られる」が伝わっているか（#27）を見る。
    static func firstLandscape(minutesSinceJoin: Int?) {
        log("first_landscape", params: ["minutes_since_join": minutesSinceJoin ?? -1])
    }

    private static func log(_ name: String, params: [String: Any]) {
        #if DEBUG
        print("📊 \(name) \(params)")
        #endif
        Analytics.logEvent(name, parameters: params)
    }
}
