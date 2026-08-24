import Foundation

/// 検証中でまだ確定していない仕様をまとめておく場所。
/// UI・ロジックはこのフラグだけを見て判断するので、値を変えるだけで挙動を戻せる。
enum RotashFeatureFlags {
    /// 撮影済みの枠を撮り直せるかどうか。
    /// 現在は仮で false（撮ったら確定）。
    /// true に戻すと AppViewModel.canShoot 経由で ThisWeekView 側のコードは
    /// 変更なしで撮り直し（SHOOT / RETAKE 表示・ライブビュー優先表示を含む）が復活する。
    static let allowRetake = false
}
