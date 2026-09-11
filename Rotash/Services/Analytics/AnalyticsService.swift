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

    /// 招待コードで参加した。
    static func groupJoined() {
        log("group_joined", params: [:])
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
    static func workShareCompleted(isComplete: Bool) {
        log("work_share_completed", params: ["is_complete": isComplete])
    }

    private static func log(_ name: String, params: [String: Any]) {
        #if DEBUG
        print("📊 \(name) \(params)")
        #endif
        Analytics.logEvent(name, parameters: params)
    }
}
