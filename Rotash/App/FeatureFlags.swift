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

    /// 共有画像の形。
    ///
    /// いまは `.screen`（撮影画面と同じ横長の7分割）。
    /// 受け取った人が画像とアプリを結びつけられることを、写真の写る量より優先している。
    ///
    /// 「縦長の枠に撮るより横長7分割のほうがよい」というフィードバックが固まったら、
    /// `.story`（9:16 の縦）に変える。描画はどちらも同じ手続きなので、この1行で入れ替わる。
    static let shareCardFormat: ShareCardFormat = .screen

    /// 検証中のビルドかどうか。TestFlight と開発ビルドで true、App Store 版では false。
    ///
    /// 「動きを確かめるための仕掛け」は、確かめている間しか要らない。
    /// 出したまま公開すると、説明の要るものが増えるだけでなく、
    /// 自由撮影モードのように **競合を自分から作り出す** ものまで届いてしまう。
    ///
    /// TestFlight のアプリは Sandbox のレシートを持つので、それで見分ける。
    /// 判定に失敗したときは「本番」に倒す（検証用の仕掛けを誤って出さない方に倒す）。
    static var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}
