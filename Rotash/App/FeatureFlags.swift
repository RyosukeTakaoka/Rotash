import Foundation

/// 検証中でまだ確定していない仕様をまとめておく場所。
/// UI・ロジックはこのフラグだけを見て判断するので、値を変えるだけで挙動を戻せる。
enum RotashFeatureFlags {
    /// 撮影済みの枠を撮り直せるかどうか。
    /// 現在は仮で false（撮ったら確定）。
    /// true に戻すと AppViewModel.canShoot 経由で ThisWeekView 側のコードは
    /// 変更なしで撮り直し（SHOOT / RETAKE 表示・ライブビュー優先表示を含む）が復活する。
    static let allowRetake = false

    /// 当番日を過ぎた枠を、後から撮って埋められるようにするか。
    /// 現在は false。撮られないまま終わった日は No Shot として作品に残る
    /// （「その日には写真がなかった」という状態そのものを作品の一部として扱う）。
    /// true にすると、過去の自分の当番日をあとから撮って埋められるようになる。
    static let allowCatchUpShooting = false
}
